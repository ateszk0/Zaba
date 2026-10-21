import '../../../l10n/generated/app_localizations.dart';
import '../domain/auth_repository.dart';

String authFailureMessage(AppLocalizations l10n, AuthFailureReason reason) {
  return switch (reason) {
    AuthFailureReason.invalidCredentials => l10n.authErrorInvalidCredentials,
    AuthFailureReason.emailTaken => l10n.authErrorEmailTaken,
    AuthFailureReason.weakPassword => l10n.authErrorWeakPassword,
    AuthFailureReason.emailNotConfirmed => l10n.authErrorEmailNotConfirmed,
    AuthFailureReason.tooManyRequests => l10n.authErrorTooManyRequests,
    AuthFailureReason.network => l10n.authErrorNetwork,
    AuthFailureReason.unknown => l10n.authErrorUnknown,
  };
}
