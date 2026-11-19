import SwiftUI

@available(iOS 13.0, *)
struct NotificationsView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        NavigationView {
            List(store.notifications, id: \.self) { n in
                Text(n)
            }
            .listStyle(.plain)
            .navigationBarTitle("Notifications", displayMode: .inline)
            .navigationBarItems(trailing: Button(action: { Task { await store.loadNotifications() } }) { Image(systemName: "arrow.clockwise") })
        }
        .navigationViewStyle(.stack)
        .onAppear { Task { await store.loadNotifications() } }
    }
}