#!/usr/bin/env python3
"""
Script to fix the Info.plist duplication by removing INFOPLIST_FILE setting
and letting Xcode auto-generate it.
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

def fix_build_settings(lines):
    """Remove the exceptions list and change GENERATE_INFOPLIST_FILE to YES."""
    
    # First, remove the exceptions list from the file system group
    idx = find_line(lines, 'exceptions = (')
    if idx >= 0:
        # Remove the exceptions block (3 lines)
        del lines[idx:idx+3]
        print("Removed exceptions list from file system group")
    
    # Now change GENERATE_INFOPLIST_FILE from NO to YES in both debug and release
    for i in range(len(lines)):
        if 'GENERATE_INFOPLIST_FILE = NO;' in lines[i] and i > 0:
            # Check if this is in the widget config by looking at nearby lines
            context = ''.join(lines[max(0, i-20):i+5])
            if 'continuumWidget' in context or 'orion-labs.continuum.continuumWidget' in context:
                lines[i] = lines[i].replace('GENERATE_INFOPLIST_FILE = NO;', 'GENERATE_INFOPLIST_FILE = YES;')
                print(f"Changed GENERATE_INFOPLIST_FILE to YES at line {i}")
        
        # Also remove the INFOPLIST_FILE setting
        if 'INFOPLIST_FILE = continuumWidget/Info.plist;' in lines[i]:
            del lines[i]
            print(f"Removed INFOPLIST_FILE setting at line {i}")
            # After deletion, check the same index again
            if i < len(lines) and 'INFOPLIST_FILE = continuumWidget/Info.plist;' in lines[i]:
                del lines[i]
                print(f"Removed second INFOPLIST_FILE setting at line {i}")
    
    return lines

def main():
    """Main function."""
    print("Reading project.pbxproj...")
    lines = read_project()
    
    print("\nFixing widget Info.plist configuration...")
    modified_lines = fix_build_settings(lines)
    
    print("\nWriting modified project.pbxproj...")
    write_project(modified_lines)
    
    print("\n✅ Successfully fixed Info.plist configuration!")
    print("\nChanges made:")
    print("1. Removed exceptions list from file system group")
    print("2. Changed GENERATE_INFOPLIST_FILE from NO to YES")
    print("3. Removed INFOPLIST_FILE setting")
    print("\nThis will let Xcode auto-generate the Info.plist from the source file.")

if __name__ == '__main__':
    main()
