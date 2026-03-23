# Contributing to SmartStay 🤝

Thank you for considering contributing to SmartStay! This guide will help you get started.

---

## 🐛 Reporting Bugs

1. **Search existing issues** to avoid duplicates
2. Open a new issue with:
   - Clear title describing the bug
   - Steps to reproduce
   - Expected vs actual behavior
   - Screenshots if applicable
   - Flutter version (`flutter --version`)

---

## 💡 Suggesting Features

1. Open a new issue with the **"Feature Request"** label
2. Describe the feature and its use case
3. Include mockups or wireframes if possible

---

## 🔧 Submitting a Pull Request

1. **Fork** the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Make your changes
4. Test on at least one platform (Web or Android)
5. Commit with a descriptive message: `git commit -m "Add: brief description"`
6. Push to your fork: `git push origin feature/your-feature-name`
7. Open a Pull Request against `main`

### PR Checklist

- [ ] Code compiles without errors
- [ ] No hardcoded credentials or API keys
- [ ] Follows existing code style (see below)
- [ ] Tested on at least one platform

---

## 🎨 Code Style Guidelines

### Design System

This project uses a custom design system defined in `lib/utils/admin_design_system.dart`:

- **Colors**: Use `AdminColors.*` constants (e.g., `AdminColors.primary`, `AdminColors.textMuted`)
- **Gradients**: Use `AdminGradients.*` (e.g., `AdminGradients.primary`, `AdminGradients.headerLight`)
- **Shadows**: Use `AdminShadows.*` for consistent elevation
- **Typography**: Always use `fontFamily: 'Inter'` — do not introduce other fonts

### Dart Conventions

- Use `const` constructors where possible
- Prefer named parameters for widget constructors
- Keep widgets focused and modular
- Use meaningful variable names
- Add comments for complex Firestore queries

### File Organization

- **Screens** go in `lib/screens/`
- **Reusable widgets** go in `lib/widgets/`
- **Business logic / services** go in `lib/services/`
- **Themes & colors** go in `lib/theme/` or `lib/utils/`
- **Config / env** go in `lib/config/`

---

## ⚠️ Security Rules

> **NEVER commit these files:**
>
> - `lib/firebase_options.dart` — Firebase project config
> - `lib/config/env.dart` — PayU credentials
> - `android/app/google-services.json` — Android Firebase config
> - `ios/Runner/GoogleService-Info.plist` — iOS Firebase config
>
> These are listed in `.gitignore`. If you accidentally commit them, use:
> ```bash
> git rm --cached <file>
> ```

---

## 📜 License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
