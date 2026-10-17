import SwiftUI

struct RootRouterView: View {
    @State private var router = AppRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    router.destination(for: route)
                }
        }
        .sheet(item: $router.sheet) { route in
            sheetDestination(for: route)
        }
        .fullScreenCover(item: $router.fullScreenCover) { route in
            fullScreenDestination(for: route)
        }
        .alert(item: $router.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: alert.message.map(Text.init)
            )
        }
        .environment(router)
    }

    @ViewBuilder
    private func sheetDestination(for route: SheetRoute) -> some View {
        switch route {
        case .placeholder:
            EmptyView()
        case .createSession:
            NavigationStack {
                CreateSessionView()
            }
            .presentationSizing(.page)
        }
    }

    @ViewBuilder
    private func fullScreenDestination(for route: FullScreenRoute) -> some View {
        switch route {
        case .placeholder:
            EmptyView()
        }
    }
}
