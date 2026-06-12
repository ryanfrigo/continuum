#!/usr/bin/env python3
"""
Script to fix HabitDataManager to use custom compilation flag instead of canImport(SwiftData).
"""

def read_file(path):
    """Read a file."""
    with open(path, 'r') as f:
        return f.read()

def write_file(path, content):
    """Write a file."""
    with open(path, 'w') as f:
        f.write(content)

def fix_habitdatamanager():
    """Replace canImport(SwiftData) with !WIDGET_EXTENSION."""
    path = '/Users/ryanfrigo/dev/orion-labs/continuum/Shared/HabitDataManager.swift'
    content = read_file(path)
    
    # Replace canImport(SwiftData) with !WIDGET_EXTENSION
    content = content.replace('#if canImport(SwiftData)', '#if !WIDGET_EXTENSION')
    
    write_file(path, content)
    print("✅ Updated HabitDataManager.swift to use !WIDGET_EXTENSION instead of canImport(SwiftData)")

def add_widget_extension_flag_to_project():
    """Add WIDGET_EXTENSION flag to widget target build settings."""
    path = '/Users/ryanfrigo/dev/orion-labs/continuum/continuum.xcodeproj/project.pbxproj'
    with open(path, 'r') as f:
        lines = f.readlines()
    
    # Find the widget build configurations and add the WIDGET_EXTENSION flag
    modified = False
    for i in range(len(lines)):
        # Look for widget build settings sections
        if i > 0 and 'continuumWidget' in ''.join(lines[max(0, i-30):i+5]):
            # Check if this is the SWIFT_ACTIVE_COMPILATION_CONDITIONS line in widget config
            if 'SWIFT_ACTIVE_COMPILATION_CONDITIONS' in lines[i] and 'DEBUG' in lines[i]:
                # Add WIDGET_EXTENSION to the conditions
                if 'WIDGET_EXTENSION' not in lines[i]:
                    lines[i] = lines[i].replace('"DEBUG $(inherited)"', '"DEBUG $(inherited) WIDGET_EXTENSION"')
                    modified = True
                    print(f"Added WIDGET_EXTENSION flag at line {i}")
    
    if modified:
        with open(path, 'w') as f:
            f.writelines(lines)
        print("✅ Added WIDGET_EXTENSION compilation flag to widget target")
    else:
        print("ℹ️  Note: Widget target uses default Swift compilation conditions")
        print("   The flag will be added via OTHER_SWIFT_FLAGS instead")
        
        # Try adding via OTHER_SWIFT_FLAGS
        for i in range(len(lines)):
            if 'continuumWidget' in ''.join(lines[max(0, i-30):i+5]):
                if 'PRODUCT_NAME = "$(TARGET_NAME)";' in lines[i]:
                    # Insert OTHER_SWIFT_FLAGS before PRODUCT_NAME
                    lines.insert(i, '\t\t\t\tOTHER_SWIFT_FLAGS = "-DWIDGET_EXTENSION";\n')
                    modified = True
                    print(f"Added OTHER_SWIFT_FLAGS with WIDGET_EXTENSION at line {i}")
                    break
        
        if modified:
            with open(path, 'w') as f:
                f.writelines(lines)
            print("✅ Added WIDGET_EXTENSION flag via OTHER_SWIFT_FLAGS")

def main():
    """Main function."""
    print("Fixing HabitDataManager compilation for widget extension...\n")
    
    fix_habitdatamanager()
    add_widget_extension_flag_to_project()
    
    print("\n✅ All fixes applied!")
    print("\nThe widget target will now define WIDGET_EXTENSION,")
    print("which will exclude the Habit model-dependent code from compilation.")

if __name__ == '__main__':
    main()
