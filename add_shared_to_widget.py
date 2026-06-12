#!/usr/bin/env python3
"""
Script to add the Shared folder to the widget target's fileSystemSynchronizedGroups.
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

def add_shared_to_widget(lines):
    """Add Shared folder to widget target's fileSystemSynchronizedGroups."""
    
    # Find the widget target
    idx = find_line(lines, '6DA1B0CA91254684BFE54F32 /* continuumWidget */ = {')
    if idx < 0:
        print("Could not find widget target")
        return lines
    
    # Find fileSystemSynchronizedGroups within this target
    for i in range(idx, min(idx + 50, len(lines))):
        if 'fileSystemSynchronizedGroups = (' in lines[i]:
            # Find the closing of this array
            for j in range(i + 1, min(i + 10, len(lines))):
                if ');' in lines[j]:
                    # Insert the Shared folder reference before the closing
                    lines.insert(j, '\t\t\t\tDA112F502E9464AC004FF4C9 /* Shared */,\n')
                    print("Added Shared folder to widget target's fileSystemSynchronizedGroups")
                    return lines
    
    print("Could not find fileSystemSynchronizedGroups in widget target")
    return lines

def main():
    """Main function."""
    print("Reading project.pbxproj...")
    lines = read_project()
    
    print("\nAdding Shared folder to widget target...")
    modified_lines = add_shared_to_widget(lines)
    
    print("\nWriting modified project.pbxproj...")
    write_project(modified_lines)
    
    print("\n✅ Successfully added Shared folder to widget target!")
    print("\nThe widget should now be able to access HabitData and HabitDataManager.")

if __name__ == '__main__':
    main()
