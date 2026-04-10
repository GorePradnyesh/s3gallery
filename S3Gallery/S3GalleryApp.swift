import SwiftUI

@main
struct S3GalleryApp: App {
    @State private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(authViewModel: authViewModel)
                .task { await bootstrap() }
        }
    }

    private func bootstrap() async {
#if DEBUG
        if UITestArgs.isUITesting {
            if UITestArgs.skipLogin {
                // Inject a mock service and skip straight to the browser.
                let service = UITestMockS3Service(shouldSucceed: true)
                authViewModel.injectMockAuthentication(service: service)
            }
            // --no-keychain: don't restore any existing session — show login.
            // --mock-s3-success / --mock-s3-failure without --skip-login:
            //   show login screen; AuthViewModel uses the factory set below.
            if UITestArgs.mockSuccess || UITestArgs.mockFailure {
                let succeed = UITestArgs.mockSuccess
                authViewModel.overrideServiceFactory { _ in
                    UITestMockS3Service(shouldSucceed: succeed)
                }
            }
            if !UITestArgs.noKeychain && !UITestArgs.skipLogin {
                await authViewModel.checkExistingCredentials()
            }
            return
        }
#endif
        await authViewModel.checkExistingCredentials()
    }
}

struct RootView: View {
    @Bindable var authViewModel: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme

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
        .fontWeight(.light)
        .foregroundStyle(colorScheme == .dark ? Color.white : Color.primary)
    }
}
