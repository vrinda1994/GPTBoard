# GPTBoard - AI-Powered iOS Custom Keyboard

## Project Overview
GPTBoard is an iOS custom keyboard extension that uses AI to transform text in different conversational styles and contexts. Users type normally, then switch to GPTBoard to apply AI transformations like making text funny, snarky, romantic, etc.

## Architecture

### Main App (`GPTBoard/`)
- **ContentView.swift**: Complete SwiftUI app with consolidated auth flow, keyboard setup instructions, and settings
- **App.swift**: Main app entry point
- Uses Firebase Authentication with email/password
- Guides users through keyboard setup process
- Manages authentication state and token refresh

### Custom Keyboard Extension (`CustomKeyboard/`)
- **KeyboardViewController.swift**: Main keyboard implementation
- **Info.plist**: Keyboard extension configuration
- Requires "Allow Full Access" for internet connectivity
- Shares authentication state via App Groups (`group.com.mmcm.gptboard`)

## Key Features

### Authentication System
- Firebase Auth with JWT token validation
- Automatic token refresh every 30 minutes
- Shared UserDefaults between main app and keyboard extension
- App Group: `group.com.mmcm.gptboard`
- Keys: `userUID`, `firebaseIDToken`, `userIsAuthenticated`

### Text Transformation Contexts
9 predefined transformation styles:
1. 😂 Funny - "How would you say this sentence in a funny way"
2. 😏 Snarky - "Make this sentence snarky"
3. 🤓 Witty - "Make this sentence witty"
4. 🤬 Insult - "Convert this sentence into an insult"
5. 🔥 GenZ - "How would a genz say this line"
6. 🙃 Millennial - "How would a millennial say this line"
7. Emojis - "Convert this sentence into all emojis"
8. 🏰 Medieval - "Make this sentence into how they would say it in medieval times"
9. 🥰 Romantic - "How would you say this in a romantic way"

### Keyboard Functionality
- **Text History Stack**: Maintains history for undo/redo operations
- **Action Buttons**: Undo, Clear, Regenerate, Keyboard Switch
- **Loading States**: Animated dotted borders during API calls
- **Suggestion Cycling**: Multiple suggestions per transformation, can regenerate
- **Active Button Highlighting**: Visual feedback for applied transformations

### UI Design
- **Glass Morphism Effects**: Modern blur and transparency effects
- **Gradient Buttons**: Each context has unique color gradients
- **3x3 Grid Layout**: Organized button layout for transformations
- **Responsive Design**: Adapts to different screen sizes and orientations
- **Animation System**: Touch feedback, loading states, and action animations

## Technical Implementation

### State Management
- **AuthViewModel**: Handles login/logout, token management
- **KeyboardStatusChecker**: Monitors keyboard installation and permissions
- **Text History**: Stack-based undo/redo system
- **Caching**: UI view caching for performance, authentication state caching

### API Integration
- **APIManager**: Handles communication with AI service (appears to use GCP backend)
- **Error Handling**: 401 authentication errors trigger re-authentication flow
- **Request Management**: Prevents multiple simultaneous requests

### User Experience Flow
1. User opens main app and authenticates
2. App guides through iOS keyboard setup (Settings > Keyboards)
3. User enables "Allow Full Access" for internet connectivity
4. User types text in any app using system keyboard
5. User switches to GPTBoard keyboard (globe icon)
6. GPTBoard shows transformation options if text exists
7. User selects transformation style
8. AI processes and replaces text
9. User can undo, regenerate, or apply different transformations

## Dependencies
- **Firebase Auth**: User authentication
- **Alamofire**: HTTP networking for API calls
- **UIKit**: Custom keyboard UI (not SwiftUI for keyboard extension)
- **CocoaPods**: Dependency management

## App Store Configuration
- **Bundle ID**: `com.mmcm.gptboard`
- **App Group**: `group.com.mmcm.gptboard`
- **Keyboard Extension**: Requires "Allow Full Access" capability
- **Privacy**: Keyboard access requires user consent

## Development Notes
- Main app uses SwiftUI, keyboard extension uses UIKit
- Authentication tokens cached for 5 seconds to reduce UserDefaults access
- JWT token validation performed locally before API calls
- Keyboard automatically switches to system keyboard on first launch
- Glass morphism effects adapt to light/dark mode
- View caching implemented for performance optimization

## File Structure
```
GPTBoard/
├── GPTBoard/
│   ├── ContentView.swift (main app UI + auth)
│   ├── GPTBoardApp.swift
│   └── Info.plist
├── CustomKeyboard/
│   ├── KeyboardViewController.swift (keyboard implementation)
│   └── Info.plist
├── GPTBoard.xcodeproj/
├── Podfile & Podfile.lock
└── Pods/
```

## Commands to Run
- Build: `CMD+B` in Xcode
- Run main app: `CMD+R` in Xcode
- Test keyboard: Install app, enable in Settings > Keyboards, test in Messages or Notes
- Clean: `CMD+Shift+K` in Xcode

## Common Issues
- Keyboard requires "Allow Full Access" for API calls
- App Group must match between main app and keyboard extension
- Firebase configuration must be properly set up
- Keyboard may need to be re-enabled after app updates