import SwiftUI

@main
struct S3GalleryApp: App {
    @State private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(authViewModel: authViewModel)
                .task {
                    await authViewModel.checkExistingCredentials()
                }
        }
    }
}

struct RootView: View {
    @Bindable var authViewModel: AuthViewModel

    var body: some View {
        Group {
            if authViewModel.isAuthenticated,
               let service = authViewModel.activeService,
               let credentials = authViewModel.credentials {
                BrowserView(
                    viewModel: BrowserViewModel(s3Service: service),
                    credentials: credentials,
                    onLogout: { authViewModel.logout() }
                )
            } else {
                LoginView(viewModel: authViewModel)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authViewModel.isAuthenticated)
    }
}
