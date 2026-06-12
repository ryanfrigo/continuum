#!/usr/bin/env python3
"""
Script to properly fix the Info.plist duplication by adding a
PBXFileSystemSynchronizedBuildFileExceptionSet.
"""

import uuid

def generate_uuid():
    """Generate a unique 24-character hex ID matching Xcode's format."""
    return uuid.uuid4().hex[:24].upper()

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

def fix_infoplist_exceptions(lines):
    """Add proper exception set for Info.plist."""
    
    exception_uuid = generate_uuid()
    print(f"Generated exception set UUID: {exception_uuid}")
    
    # 1. Add PBXFileSystemSynchronizedBuildFileExceptionSet section (after PBXContainerItemProxy)
    idx = find_line(lines, '/* End PBXContainerItemProxy section */')
    if idx >= 0:
        lines.insert(idx + 1, '\n')
        lines.insert(idx + 2, '/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */\n')
        lines.insert(idx + 3, f'\t\t{exception_uuid} /* Exceptions for "continuumWidget" */ = {{\n')
        lines.insert(idx + 4, '\t\t\tisa = PBXFileSystemSynchronizedBuildFileExceptionSet;\n')
        lines.insert(idx + 5, '\t\t\tmembershipExceptions = (\n')
        lines.insert(idx + 6, '\t\t\t\tInfo.plist,\n')
        lines.insert(idx + 7, '\t\t\t);\n')
        lines.insert(idx + 8, '\t\t\ttarget = 70776688D98542999535336A /* continuumWidget */;\n')
        lines.insert(idx + 9, '\t\t};\n')
        lines.insert(idx + 10, '/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */\n')
        print("Added PBXFileSystemSynchronizedBuildFileExceptionSet section")
    
    # 2. Update the continuumWidget file system group to reference the exception set
    idx = find_line(lines, '87C4C7DD65EF45F6871E374F /* continuumWidget */ = {')
    if idx >= 0:
        # Find the line with 'isa = PBXFileSystemSynchronizedRootGroup;'
        for i in range(idx, min(idx + 10, len(lines))):
            if 'isa = PBXFileSystemSynchronizedRootGroup;' in lines[i]:
                # Insert exceptions reference after isa line
                lines.insert(i + 1, f'\t\t\texceptions = (\n')
                lines.insert(i + 2, f'\t\t\t\t{exception_uuid} /* PBXFileSystemSynchronizedBuildFileExceptionSet */,\n')
                lines.insert(i + 3, '\t\t\t);\n')
                print("Added exceptions reference to continuumWidget group")
                break
    
    return lines

def main():
    """Main function."""
    print("Reading project.pbxproj...")
    lines = read_project()
    
    print("\nAdding proper Info.plist exception set...")
    modified_lines = fix_infoplist_exceptions(lines)
    
    print("\nWriting modified project.pbxproj...")
    write_project(modified_lines)
    
    print("\n✅ Successfully added Info.plist exception set!")
    print("\nThis should resolve the duplicate Info.plist error.")

if __name__ == '__main__':
    main()
