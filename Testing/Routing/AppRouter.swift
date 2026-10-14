import Observation
import SwiftUI

@Observable
final class AppRouter {
    var path = NavigationPath()
    var sheet: SheetRoute?
    var fullScreenCover: FullScreenRoute?
    var alert: AppAlert?

    func navigate(to route: AppRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }

    func replace(with route: AppRoute) {
        pop()
        navigate(to: route)
    }

    func presentSheet(_ route: SheetRoute) {
        sheet = route
    }

    func dismissSheet() {
        sheet = nil
    }

    func presentFullScreen(_ route: FullScreenRoute) {
        fullScreenCover = route
    }

    func dismissFullScreen() {
        fullScreenCover = nil
    }

    func presentAlert(_ alert: AppAlert) {
        self.alert = alert
    }

    func dismissAlert() {
        alert = nil
    }

    func destination(for route: AppRoute) -> some View {
        switch route {
        case .home:
            HomeView()
        }
    }
}
