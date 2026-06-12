#!/usr/bin/env python3
"""
Script to properly add loadAllHabitData() to HabitDataManager class.
"""

def main():
    """Main function."""
    with open('/Users/ryanfrigo/dev/orion-labs/continuum/Shared/HabitDataManager.swift', 'r') as f:
        content = f.read()
    
    # Remove the misplaced code at the end
    # Find and remove everything after the last closing brace of HabitData struct
    lines = content.split('\n')
    
    # Remove trailing lines that were added incorrectly
    while lines and any(keyword in lines[-1] for keyword in ['loadAllHabitData', 'Widget Helper Methods', 'let habitIds', 'return habitIds.compactMap']):
        lines.pop()
    
    # Now rebuild content
    content = '\n'.join(lines)
    
    # Find the end of HabitDataManager class (line with single '}' after saveHabitData method)
    # The class ends before the HabitData struct definition
    marker = 'func saveHabitData(_ habitData: HabitData) {'
    if marker in content:
        # Find this function and then find its closing brace
        parts = content.split(marker)
        before = parts[0]
        after = parts[1]
        
        # Find the end of saveHabitData method (first closing brace at start of line)
        after_lines = after.split('\n')
        insert_point = 0
        brace_count = 1  # We're inside saveHabitData
        for i, line in enumerate(after_lines):
            # Count braces
            brace_count += line.count('{') - line.count('}')
            if brace_count == 0:
                # This is the closing brace of saveHabitData
                insert_point = i + 1
                break
        
        # Insert the new method after saveHabitData and before the class closing brace
        new_method = '''
    
    // MARK: - Widget Helper Methods
    
    func loadAllHabitData() -> [HabitData] {
        let habitIds = getAllHabitIds()
        return habitIds.compactMap { getHabitData(for: $0) }
    }
'''
        
        after_lines.insert(insert_point, new_method)
        after = '\n'.join(after_lines)
        
        content = before + marker + after
        
        with open('/Users/ryanfrigo/dev/orion-labs/continuum/Shared/HabitDataManager.swift', 'w') as f:
            f.write(content)
        
        print("✅ Added loadAllHabitData() method to HabitDataManager class")
    else:
        print("❌ Could not find saveHabitData method")

if __name__ == '__main__':
    main()
