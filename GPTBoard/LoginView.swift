import SwiftUI

struct LoginView: View {
    @EnvironmentObject var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("GPTBoard")
                .font(.largeTitle)
                .fontWeight(.bold)

            TextField("Email", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

            SecureField("Password", text: $viewModel.password)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button(action: {
                viewModel.login()
            }) {
                Text("Login")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }

            Button(action: {
                viewModel.signUp()
            }) {
                Text("Don't have an account? Sign Up")
                    .font(.subheadline)
            }
        }
        .padding()
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
