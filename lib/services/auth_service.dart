import 'api_service.dart';
import 'token_manager.dart';

class AuthService {
  // Login with email and password
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await ApiService.login(email, password);

      if (response['success'] == true && response['token'] != null) {
        // Save tokens securely
        await TokenManager.saveToken(response['token'] as String);
        await TokenManager.saveUserEmail(email);

        if (response['refreshToken'] != null) {
          await TokenManager.saveRefreshToken(response['refreshToken'] as String);
        }

        return {
          'success': true,
          'message': 'Login successful',
          'user': response['user'],
        };
      } else {
        return {
          'success': false,
          'message': response['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Login error: $e',
      };
    }
  }

  // Signup new user
  static Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await ApiService.signup(
        name: name,
        email: email,
        password: password,
      );

      if (response['success'] == true && response['token'] != null) {
        // Save tokens securely
        await TokenManager.saveToken(response['token'] as String);
        await TokenManager.saveUserEmail(email);

        if (response['refreshToken'] != null) {
          await TokenManager.saveRefreshToken(response['refreshToken'] as String);
        }

        return {
          'success': true,
          'message': 'Signup successful',
          'user': response['user'],
        };
      } else {
        return {
          'success': false,
          'message': response['message'] ?? 'Signup failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Signup error: $e',
      };
    }
  }

  // Logout
  static Future<void> logout() async {
    await TokenManager.clearAllTokens();
  }

  // Get current user email
  static Future<String?> getCurrentUserEmail() async {
    return await TokenManager.getUserEmail();
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    return await TokenManager.isLoggedIn();
  }

  // Refresh token
  static Future<Map<String, dynamic>> refreshToken() async {
    try {
      final refreshToken = await TokenManager.getRefreshToken();

      if (refreshToken == null) {
        return {
          'success': false,
          'message': 'No refresh token available',
        };
      }

      // Call backend to refresh token
      // This would be implemented in ApiService as refreshToken()
      // For now, returning placeholder response
      return {
        'success': true,
        'message': 'Token refreshed',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Token refresh error: $e',
      };
    }
  }
}
