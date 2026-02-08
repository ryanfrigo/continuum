# Widget Extension Setup Instructions

The widget files have been created in the `continuumWidget/` folder. Follow these steps to add the Widget Extension target to your Xcode project:

## Step 1: Add Widget Extension Target

1. Open `continuum.xcodeproj` in Xcode
2. Click on the project in the navigator (blue icon at top)
3. At the bottom of the targets list, click the **+** button
4. Search for "Widget Extension" and select it
5. Click **Next**

## Step 2: Configure the Target

1. **Product Name**: `continuumWidget`
2. **Team**: Select your development team
3. **Bundle Identifier**: `orion-labs.continuum.continuumWidget` (or your custom bundle ID)
4. **Uncheck** "Include Configuration Intent"
5. Click **Finish**
6. When prompted "Activate 'continuumWidget' scheme?", click **Activate**

## Step 3: Replace Generated Files

Xcode will generate some default files. Delete them and use our custom ones:

1. **Delete** the generated `continuumWidget.swift` file
2. In Xcode, right-click the `continuumWidget` group
3. Select **Add Files to "continuum"...**
4. Navigate to the `continuumWidget/` folder
5. Select all files:
   - `continuumWidget.swift`
   - `continuumWidgetBundle.swift`
   - `Info.plist`
   - `Assets.xcassets` folder
6. **Important**: Make sure "Copy items if needed" is **UNCHECKED**
7. **Important**: Under "Add to targets", check **continuumWidget** (not the main app)
8. Click **Add**

## Step 4: Share Code Between Targets

The widget needs access to `HabitData` and `HabitDataManager`:

1. In the Project Navigator, find `Shared/HabitDataManager.swift`
2. Click on it, then open the File Inspector (right panel)
3. Under "Target Membership", check **both**:
   - ✅ continuum
   - ✅ continuumWidget
4. Do the same for any other shared model files if needed

## Step 5: Configure App Groups

The widget needs to share data with the main app:

### Main App Target:
1. Select the **continuum** target
2. Go to **Signing & Capabilities**
3. If "App Groups" isn't there, click **+ Capability** and add "App Groups"
4. Click **+** and add: `group.com.orionlabs.continuum`
   (Or use: `group.YOUR_BUNDLE_ID` if using a custom bundle ID)

### Widget Target:
1. Select the **continuumWidget** target
2. Go to **Signing & Capabilities**
3. Add "App Groups" capability (if not present)
4. Use the **same** App Group: `group.com.orionlabs.continuum`

## Step 6: Update HabitDataManager

Make sure `HabitDataManager` uses the correct app group. Open `Shared/HabitDataManager.swift` and verify:

```swift
private let appGroupID = "group.com.orionlabs.continuum"
```

## Step 7: Build and Run

1. Select the **continuum** scheme (not continuumWidget)
2. Build and run on a device or simulator (⌘R)
3. On your home screen, long-press to enter jiggle mode
4. Tap the **+** button in the top-left
5. Search for "Continuum"
6. Choose between:
   - **Small Widget**: Shows overall health with color ring
   - **Medium Widget**: Shows your habits list with completion status

## Widget Features

### Small Widget (2x2)
- Overall health percentage
- Color-coded ring (orange → green → cyan)
- Habit count

### Medium Widget (4x2)
- Today's completion status (X/Y completed)
- Up to 3 habits with:
  - Checkmark if completed today
  - Habit name
  - Current streak count
- Shows "+X more" if you have more than 3 habits

### Updates
- Widgets automatically update at midnight each day
- Manually refreshed when you complete habits in the app
- Uses the same dynamic color system as the main app

## Troubleshooting

**Widget shows "Unable to Load":**
- Make sure App Groups are configured correctly on both targets
- Verify both targets use the same App Group ID
- Check that HabitDataManager.swift is included in both targets

**Widget shows placeholder:**
- Run the main app first to create some habits
- Complete at least one habit to see the widgets populate
- Wait a moment for the timeline to refresh

**Build errors:**
- Make sure all Shared files are added to both targets
- Verify the Info.plist is correctly configured
- Clean build folder (⇧⌘K) and rebuild

## Need Help?

If you run into issues, the key things to check are:
1. Both targets use the same App Group
2. Shared code files are included in both targets
3. Widget bundle identifier is correct (main app ID + `.continuumWidget`)

---

**Tip**: Test widgets on a real device for the best experience. Simulator widgets can be slower to update.
