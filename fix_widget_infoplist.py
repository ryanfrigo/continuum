#!/usr/bin/env python3
"""
Script to fix the Info.plist duplication issue by adding exceptions to the
PBXFileSystemSynchronizedRootGroup.
"""

def read_project():
    """Read the project.pbxproj file."""
    with open('/Users/ryanfrigo/dev/orion-labs/continuum/continuum.xcodeproj/project.pbxproj', 'r') as f:
        return f.readlines()

def write_project(lines):
    """Write the modified project.pbxproj file."""
    with open('/Users/ryanfrigo/dev/orion-labs/continuum/continuum.xcodeproj/project.pbxproj', 'w') as f:
        f.writelines(lines)

def find_line(lines, search_str):
    """Find the index of a line containing the search string."""
    for i, line in enumerate(lines):
        if search_str in line:
            return i
    return -1

def fix_widget_group(lines):
    """Add exceptions to the widget file system synchronized group."""
    
    # Find the continuumWidget PBXFileSystemSynchronizedRootGroup
    idx = find_line(lines, '/* continuumWidget */ = {')
    if idx < 0:
        print("Could not find continuumWidget group")
        return lines
    
    # Make sure it's the file system synchronized group
    found_group = False
    for i in range(idx, min(idx + 10, len(lines))):
        if 'PBXFileSystemSynchronizedRootGroup' in lines[i]:
            found_group = True
            break
    
    if not found_group:
        print("continuumWidget is not a PBXFileSystemSynchronizedRootGroup")
        return lines
    
    # Find where to insert the exceptions (before path = )
    for i in range(idx, min(idx + 10, len(lines))):
        if 'path = continuumWidget;' in lines[i]:
            # Insert exceptions before this line
            lines.insert(i, '\t\t\texceptions = (\n')
            lines.insert(i + 1, '\t\t\t\tInfo.plist,\n')
            lines.insert(i + 2, '\t\t\t);\n')
            print("Added exceptions to exclude Info.plist from automatic inclusion")
            return lines
    
    print("Could not find path line in continuumWidget group")
    return lines

def main():
    """Main function."""
    print("Reading project.pbxproj...")
    lines = read_project()
    
    print("\nFixing widget Info.plist duplication...")
    modified_lines = fix_widget_group(lines)
    
    print("\nWriting modified project.pbxproj...")
    write_project(modified_lines)
    
    print("\n✅ Successfully fixed Info.plist issue!")
    print("\nNext steps:")
    print("1. Build the project again")
    print("2. The duplicate Info.plist error should be resolved")

if __name__ == '__main__':
    main()
