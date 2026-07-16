import Foundation
import Supabase

/// Watches one or more Postgres change streams on a single Realtime channel and calls `onChange`
/// whenever any of them fire, so a screen can live-update without polling. Reconciles once on
/// connect, then again on every change. Runs until the enclosing task is cancelled, at which point
/// the channel is torn down.
///
/// Drives the live Home feed, the live Drop Detail grid, and the notification bell badge. All three
/// just refetch in `onChange` — reusing the existing (RLS-scoped, embed-joined) queries rather than
/// trying to reconstruct rows from raw change payloads.
enum RealtimeWatch {
    /// One table (plus an optional single-column equality filter) to listen to on the channel.
    struct Source {
        let table: String
        let filter: RealtimePostgresFilter?

        init(_ table: String, filter: RealtimePostgresFilter? = nil) {
            self.table = table
            self.filter = filter
        }
    }

    /// A raw Postgres change plus the table it came from. Screens usually refetch, but DELETE events
    /// need the old row id so removed drops can disappear before the refetch completes.
    struct Event {
        let table: String
        let action: AnyAction

        var deletedRecordID: UUID? {
            guard case let .delete(action) = action else { return nil }
            return try? action.decodeOldRecord(as: DeletedRecord.self, decoder: JSONDecoder()).id
        }
    }

    /// - Parameters:
    ///   - topic: A stable, unique channel name — include the user/drop id so channels don't collide.
    ///   - sources: Tables/filters to subscribe to. Every callback is registered *before* subscribe,
    ///     which the SDK requires.
    ///   - onEvent: Invoked for every realtime event before `onChange`; use this for instant local
    ///     reactions that can be derived directly from the payload, such as removing deleted drops.
    ///   - onChange: Invoked once right after connect (to reconcile) and again on every change event.
    static func run(
        topic: String,
        sources: [Source],
        onEvent: (@MainActor (Event) async -> Void)? = nil,
        onChange: @escaping @MainActor () async -> Void
    ) async {
        let client = SupabaseClient.shared

        // `channel(_:)` caches by topic and hands back an already-subscribed instance on re-entry
        // (e.g. after an account switch re-runs the `.task`), which then rejects new `postgresChange`
        // callbacks with "after subscribe()". Drop any stale cached channel first so we always build
        // a fresh, pre-subscribe one.
        await client.removeChannel(client.channel(topic))

        let channel = client.channel(topic)
        let streams = sources.map { source -> (table: String, stream: AsyncStream<AnyAction>) in
            let stream: AsyncStream<AnyAction>
            if let filter = source.filter {
                stream = channel.postgresChange(
                    AnyAction.self, schema: "public", table: source.table, filter: filter
                )
            } else {
                stream = channel.postgresChange(AnyAction.self, schema: "public", table: source.table)
            }
            return (table: source.table, stream: stream)
        }

        // `subscribeWithError` throws if the channel can't join; on failure just bail — the screen
        // keeps whatever it last fetched.
        do {
            try await channel.subscribeWithError()
        } catch {
            return
        }

        // Reconcile once on connect so the screen is correct even for anything that changed while we
        // were subscribing.
        await onChange()

        // One child task per source; any event triggers a refetch. Force the channel down on
        // cancellation so the source streams end and `waitForAll` returns promptly.
        await withTaskCancellationHandler {
            await withTaskGroup(of: Void.self) { group in
                for (table, stream) in streams {
                    group.addTask {
                        for await action in stream {
                            if let onEvent {
                                await onEvent(Event(table: table, action: action))
                            }
                            await onChange()
                        }
                    }
                }
                await group.waitForAll()
            }
        } onCancel: {
            Task { await client.removeChannel(channel) }
        }

        await client.removeChannel(channel)
    }

    private struct DeletedRecord: Decodable {
        let id: UUID
    }
}
