#!/usr/bin/env python3
"""
Script to properly add loadAllHabitData() to HabitDataManager class.
"""

def read_file(path):
    """Read a file."""
    with open(path, 'r') as f:
        return f.readlines()

def write_file(path, lines):
    """Write a file."""
    with open(path, 'w') as f:
        f.writelines(lines)

def fix_load_all_habit_data():
    """Add loadAllHabitData() method to HabitDataManager class."""
    path = '/Users/ryanfrigo/dev/orion-labs/continuum/Shared/HabitDataManager.swift'
    lines = read_file(path)
    
    # Remove the misplaced code at the end
    while lines and (lines[-1].strip().startswith('func loadAllHabitData') or 
                     lines[-1].strip().startswith('let habitIds') or 
                     lines[-1].strip().startswith('return habitIds') or
                     lines[-1].strip() == '// MARK: - Widget Helper Methods' or
                     lines[-1].strip() == '}' and 'loadAllHabitData' in ''.join(lines[-5:])):
        if 'loadAllHabitData' in lines[-1] or '// MARK: - Widget Helper Methods' in lines[-1]:
            lines.pop()
        elif lines[-1].strip() == 'let habitIds = getAllHabitIds()':
            lines.pop()
        elif lines[-1].strip().startswith('return habitIds.compactMap'):
            lines.pop()
        elif lines[-1].strip() == '}' and i > 0:
            # Check if this is the closing brace of loadAllHabitData
            prev_line = lines[-2] if len(lines) >= 2 else ''
            if 'habitIds.compactMap' in prev_line or 'getAllHabitIds' in prev_line:
                lines.pop()
            else:
                break
        else:
            break
    
    # Find line 107 (end of HabitDataManager class) 
    for i in range(len(lines)):
        if i > 0 and lines[i].strip() == '}':
            # Check if the previous lines contain HabitDataManager class methods
            context = ''.join(lines[max(0, i-20):i])
            if 'saveHabitData' in context and 'class HabitDataManager' in ''.join(lines[:i]):
                # Found the end of HabitDataManager class
                # Insert the method before the closing brace
                lines.insert(i, '    \n')
                lines.insert(i + 1, '    // MARK: - Widget Helper Methods\n')
                lines.insert(i + 2, '    \n')
                lines.insert(i + 3, '    func loadAllHabitData() -> [HabitData] {\n')
                lines.insert(i + 4, '        let habitIds = getAllHabitIds()\n')
                lines.insert(i + 5, '        return habitIds.compactMap { getHabitData(for: $0) }\n')
                lines.insert(i + 6, '    }\n')
                print(f"✅ Added loadAllHabitData() method at line {i}")
                break
    
    write_file(path, lines)

def main():
    """Main function."""
    print("Adding loadAllHabitData() method to HabitDataManager class...\n")
    fix_load_all_habit_data()
    print("\n✅ Method added successfully!")

if __name__ == '__main__':
    main()
