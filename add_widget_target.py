#!/usr/bin/env python3
"""
Script to add continuumWidget as a proper target to the Xcode project.
Based on the WakeEarly widget target structure.
"""

import re
import uuid
import sys

def generate_uuid():
    """Generate a unique 24-character hex ID matching Xcode's format."""
    return uuid.uuid4().hex[:24].upper()

def read_project():
    """Read the project.pbxproj file."""
    with open('/Users/ryanfrigo/dev/orion-labs/continuum/continuum.xcodeproj/project.pbxproj', 'r') as f:
        return f.read()

def write_project(content):
    """Write the modified project.pbxproj file."""
    with open('/Users/ryanfrigo/dev/orion-labs/continuum/continuum.xcodeproj/project.pbxproj', 'w') as f:
        f.write(content)

def add_widget_target(content):
    """Add the widget extension target to the project."""
    
    # Generate UUIDs for all the objects we need to create
    uuids = {
        'widget_appex': generate_uuid(),  # continuumWidget.appex file reference
        'widget_target': generate_uuid(),  # continuumWidget target
        'widget_buildconfig_debug': generate_uuid(),
        'widget_buildconfig_release': generate_uuid(),
        'widget_buildconfig_list': generate_uuid(),
        'widget_sources_phase': generate_uuid(),
        'widget_frameworks_phase': generate_uuid(),
        'widget_resources_phase': generate_uuid(),
        'widget_filesystem_group': generate_uuid(),
        'widgetkit_framework': generate_uuid(),
        'swiftui_framework': generate_uuid(),
        'frameworks_group': generate_uuid(),
        'embed_extension_phase': generate_uuid(),
        'embed_extension_buildfile': generate_uuid(),
        'widget_dependency': generate_uuid(),
        'widget_target_dependency': generate_uuid(),
        'widgetkit_buildfile': generate_uuid(),
        'swiftui_buildfile': generate_uuid(),
    }
    
    print(f"Generated UUIDs:")
    for key, value in uuids.items():
        print(f"  {key}: {value}")
    
    # 1. Add file references for widget.appex and frameworks
    file_ref_section = re.search(r'/\* Begin PBXFileReference section \*/.*?/\* End PBXFileReference section \*/', content, re.DOTALL)
    if file_ref_section:
        new_file_refs = f'''\t\t{uuids['widget_appex']} /* continuumWidget.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = continuumWidget.appex; sourceTree = BUILT_PRODUCTS_DIR; }};
\t\t{uuids['widgetkit_framework']} /* WidgetKit.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = WidgetKit.framework; path = System/Library/Frameworks/WidgetKit.framework; sourceTree = SDKROOT; }};
\t\t{uuids['swiftui_framework']} /* SwiftUI.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = SwiftUI.framework; path = System/Library/Frameworks/SwiftUI.framework; sourceTree = SDKROOT; }};
'''
        content = content.replace(file_ref_section.group(0), 
            file_ref_section.group(0).replace('/* End PBXFileReference section */', 
                new_file_refs + '/* End PBXFileReference section */'))
    
    # 2. Add PBXFileSystemSynchronizedRootGroup for continuumWidget
    filesystem_section = re.search(r'/\* Begin PBXFileSystemSynchronizedRootGroup section \*/.*?/\* End PBXFileSystemSynchronizedRootGroup section \*/', content, re.DOTALL)
    if filesystem_section:
        new_filesystem_group = f'''\t\t{uuids['widget_filesystem_group']} /* continuumWidget */ = {{
\t\t\tisa = PBXFileSystemSynchronizedRootGroup;
\t\t\tpath = continuumWidget;
\t\t\tsourceTree = "<group>";
\t\t}};
'''
        content = content.replace(filesystem_section.group(0),
            filesystem_section.group(0).replace('/* End PBXFileSystemSynchronizedRootGroup section */',
                new_filesystem_group + '/* End PBXFileSystemSynchronizedRootGroup section */'))
    
    # 3. Add widget.appex to Products group
    products_group = re.search(r'DA112F352E9464AB004FF4C9 /\* Products \*/ = \{.*?children = \((.*?)\);', content, re.DOTALL)
    if products_group:
        children = products_group.group(1).strip()
        new_children = children + f'\n\t\t\t\t{uuids["widget_appex"]} /* continuumWidget.appex */,'
        content = content.replace(products_group.group(0),
            products_group.group(0).replace(children, new_children))
    
    # 4. Add continuumWidget and Frameworks to main group
    main_group = re.search(r'DA112F2B2E9464AB004FF4C9 = \{.*?children = \((.*?)\);', content, re.DOTALL)
    if main_group:
        children = main_group.group(1).strip()
        new_children = children + f'\n\t\t\t\t{uuids["widget_filesystem_group"]} /* continuumWidget */,\n\t\t\t\t{uuids["frameworks_group"]} /* Frameworks */,'
        content = content.replace(main_group.group(0),
            main_group.group(0).replace(children, new_children))
    
    # 5. Add Frameworks group
    groups_section = re.search(r'/\* Begin PBXGroup section \*/.*?/\* End PBXGroup section \*/', content, re.DOTALL)
    if groups_section:
        new_frameworks_group = f'''\t\t{uuids['frameworks_group']} /* Frameworks */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{uuids['widgetkit_framework']} /* WidgetKit.framework */,
\t\t\t\t{uuids['swiftui_framework']} /* SwiftUI.framework */,
\t\t\t);
\t\t\tname = Frameworks;
\t\t\tsourceTree = "<group>";
\t\t}};
'''
        content = content.replace(groups_section.group(0),
            groups_section.group(0).replace('/* End PBXGroup section */',
                new_frameworks_group + '/* End PBXGroup section */'))
    
    # 6. Add PBXBuildFile entries for frameworks
    buildfile_section = re.search(r'/\* Begin PBXBuildFile section \*/', content)
    if buildfile_section:
        new_buildfiles = f'''/\* Begin PBXBuildFile section */
\t\t{uuids['widgetkit_buildfile']} /* WidgetKit.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {uuids['widgetkit_framework']} /* WidgetKit.framework */; }};
\t\t{uuids['swiftui_buildfile']} /* SwiftUI.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {uuids['swiftui_framework']} /* SwiftUI.framework */; }};
\t\t{uuids['embed_extension_buildfile']} /* continuumWidget.appex in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {uuids['widget_appex']} /* continuumWidget.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};
'''
        content = content.replace('/* Begin PBXBuildFile section */', new_buildfiles)
    
    # 7. Add PBXContainerItemProxy for widget dependency
    proxy_section = re.search(r'/\* End PBXContainerItemProxy section \*/', content)
    if proxy_section:
        new_proxy = f'''\t\t{uuids['widget_dependency']} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = DA112F2C2E9464AB004FF4C9 /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {uuids['widget_target']};
\t\t\tremoteInfo = continuumWidget;
\t\t}};
/* End PBXContainerItemProxy section */'''
        content = content.replace('/* End PBXContainerItemProxy section */', new_proxy)
    
    # 8. Add Frameworks build phase for widget
    frameworks_section = re.search(r'/\* End PBXFrameworksBuildPhase section \*/', content)
    if frameworks_section:
        new_frameworks_phase = f'''\t\t{uuids['widget_frameworks_phase']} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{uuids['swiftui_buildfile']} /* SwiftUI.framework in Frameworks */,
\t\t\t\t{uuids['widgetkit_buildfile']} /* WidgetKit.framework in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */'''
        content = content.replace('/* End PBXFrameworksBuildPhase section */', new_frameworks_phase)
    
    # 9. Add Resources build phase for widget
    resources_section = re.search(r'/\* End PBXResourcesBuildPhase section \*/', content)
    if resources_section:
        new_resources_phase = f'''\t\t{uuids['widget_resources_phase']} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */'''
        content = content.replace('/* End PBXResourcesBuildPhase section */', new_resources_phase)
    
    # 10. Add Sources build phase for widget
    sources_section = re.search(r'/\* End PBXSourcesBuildPhase section \*/', content)
    if sources_section:
        new_sources_phase = f'''\t\t{uuids['widget_sources_phase']} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */'''
        content = content.replace('/* End PBXSourcesBuildPhase section */', new_sources_phase)
    
    # 11. Add PBXCopyFilesBuildPhase for embedding the extension
    # Find the end of Resources section to insert copy files section
    resources_end = re.search(r'/\* End PBXResourcesBuildPhase section \*/', content)
    if resources_end:
        copy_files_section = f'''

/* Begin PBXCopyFilesBuildPhase section */
\t\t{uuids['embed_extension_phase']} /* Embed Foundation Extensions */ = {{
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "";
\t\t\tdstSubfolderSpec = 13;
\t\t\tfiles = (
\t\t\t\t{uuids['embed_extension_buildfile']} /* continuumWidget.appex in Embed Foundation Extensions */,
\t\t\t);
\t\t\tname = "Embed Foundation Extensions";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXCopyFilesBuildPhase section */'''
        content = content.replace('/* End PBXResourcesBuildPhase section */',
            '/* End PBXResourcesBuildPhase section */' + copy_files_section)
    
    # 12. Add widget target
    native_target_section = re.search(r'/\* End PBXNativeTarget section \*/', content)
    if native_target_section:
        new_target = f'''\t\t{uuids['widget_target']} /* continuumWidget */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {uuids['widget_buildconfig_list']} /* Build configuration list for PBXNativeTarget "continuumWidget" */;
\t\t\tbuildPhases = (
\t\t\t\t{uuids['widget_sources_phase']} /* Sources */,
\t\t\t\t{uuids['widget_frameworks_phase']} /* Frameworks */,
\t\t\t\t{uuids['widget_resources_phase']} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tfileSystemSynchronizedGroups = (
\t\t\t\t{uuids['widget_filesystem_group']} /* continuumWidget */,
\t\t\t);
\t\t\tname = continuumWidget;
\t\t\tpackageProductDependencies = (
\t\t\t);
\t\t\tproductName = continuumWidget;
\t\t\tproductReference = {uuids['widget_appex']} /* continuumWidget.appex */;
\t\t\tproductType = "com.apple.product-type.app-extension";
\t\t}};
/* End PBXNativeTarget section */'''
        content = content.replace('/* End PBXNativeTarget section */', new_target)
    
    # 13. Add widget target to project targets list
    project_targets = re.search(r'targets = \((.*?)\);', content, re.DOTALL)
    if project_targets:
        targets = project_targets.group(1).strip()
        new_targets = targets + f'\n\t\t\t\t{uuids["widget_target"]} /* continuumWidget */,'
        content = content.replace(project_targets.group(0),
            project_targets.group(0).replace(targets, new_targets))
    
    # 14. Add widget to main app target dependencies
    main_target_section = re.search(r'DA112F332E9464AB004FF4C9 /\* continuum \*/ = \{.*?buildPhases = \((.*?)\);', content, re.DOTALL)
    if main_target_section:
        build_phases = main_target_section.group(1).strip()
        new_build_phases = build_phases + f'\n\t\t\t\t{uuids["embed_extension_phase"]} /* Embed Foundation Extensions */,'
        content = content.replace(main_target_section.group(0),
            main_target_section.group(0).replace(build_phases, new_build_phases))
    
    # Add dependency
    main_target_deps = re.search(r'DA112F332E9464AB004FF4C9 /\* continuum \*/ = \{.*?dependencies = \((.*?)\);', content, re.DOTALL)
    if main_target_deps:
        deps = main_target_deps.group(1).strip()
        new_deps = deps + f'\n\t\t\t\t{uuids["widget_target_dependency"]} /* PBXTargetDependency */,'
        content = content.replace(main_target_deps.group(0),
            main_target_deps.group(0).replace(deps, new_deps))
    
    # 15. Add PBXTargetDependency
    target_dep_section = re.search(r'/\* End PBXTargetDependency section \*/', content)
    if target_dep_section:
        new_target_dep = f'''\t\t{uuids['widget_target_dependency']} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {uuids['widget_target']} /* continuumWidget */;
\t\t\ttargetProxy = {uuids['widget_dependency']} /* PBXContainerItemProxy */;
\t\t}};
/* End PBXTargetDependency section */'''
        content = content.replace('/* End PBXTargetDependency section */', new_target_dep)
    
    # 16. Add widget target attributes
    target_attrs = re.search(r'TargetAttributes = \{(.*?)\};', content, re.DOTALL)
    if target_attrs:
        attrs = target_attrs.group(1).strip()
        new_attrs = attrs + f'''
\t\t\t\t\t{uuids['widget_target']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.4;
\t\t\t\t\t}};'''
        content = content.replace(target_attrs.group(0),
            target_attrs.group(0).replace(attrs, new_attrs))
    
    # 17. Add build configurations for widget
    buildconfig_section = re.search(r'/\* End XCBuildConfiguration section \*/', content)
    if buildconfig_section:
        new_configs = f'''
\t\t{uuids['widget_buildconfig_debug']} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASGEN_EXTRACT_API = NO;
\t\t\t\tASGEN_EXTRACT_API_FILENAME = continuumWidget;
\t\t\t\tASGEN_EXTRACT_API_PATH = ".asgen/";
\t\t\t\tASGEN_SETTINGS_ONLY = NO;
\t\t\t\tASGEN_TYPE = WIDGET;
\t\t\t\tASGEN_WIDGET_KIT_ONLY = YES;
\t\t\t\tASGEN_WIDGET_NAMES = "continuumWidget";
\t\t\t\tASGEN_WORKINGDIR = continuumWidget;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME = WidgetBackground;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = continuumWidget/continuumWidget.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 2;
\t\t\t\tDEVELOPMENT_TEAM = NVN2NY8GZC;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = continuumWidget/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "Continuum Widget";
\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = "";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 3.2;
\t\t\t\t"OTHER_LDFLAGS[sdk=iphonesimulator*]" = (
\t\t\t\t\t"-Xlinker",
\t\t\t\t\t"-interposable",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "orion-labs.continuum.continuumWidget";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tREGISTER_APP_GROUPS = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{uuids['widget_buildconfig_release']} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASGEN_EXTRACT_API = NO;
\t\t\t\tASGEN_EXTRACT_API_FILENAME = continuumWidget;
\t\t\t\tASGEN_EXTRACT_API_PATH = ".asgen/";
\t\t\t\tASGEN_SETTINGS_ONLY = NO;
\t\t\t\tASGEN_TYPE = WIDGET;
\t\t\t\tASGEN_WIDGET_KIT_ONLY = YES;
\t\t\t\tASGEN_WIDGET_NAMES = "continuumWidget";
\t\t\t\tASGEN_WORKINGDIR = continuumWidget;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME = WidgetBackground;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = continuumWidget/continuumWidget.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 2;
\t\t\t\tDEVELOPMENT_TEAM = NVN2NY8GZC;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = continuumWidget/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "Continuum Widget";
\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = "";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 3.2;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "orion-labs.continuum.continuumWidget";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tREGISTER_APP_GROUPS = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */'''
        content = content.replace('/* End XCBuildConfiguration section */', new_configs)
    
    # 18. Add build configuration list for widget
    configlist_section = re.search(r'/\* End XCConfigurationList section \*/', content)
    if configlist_section:
        new_configlist = f'''\t\t{uuids['widget_buildconfig_list']} /* Build configuration list for PBXNativeTarget "continuumWidget" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{uuids['widget_buildconfig_debug']} /* Debug */,
\t\t\t\t{uuids['widget_buildconfig_release']} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */'''
        content = content.replace('/* End XCConfigurationList section */', new_configlist)
    
    return content

def main():
    """Main function."""
    print("Reading project.pbxproj...")
    content = read_project()
    
    print("\nAdding widget extension target...")
    modified_content = add_widget_target(content)
    
    print("\nWriting modified project.pbxproj...")
    write_project(modified_content)
    
    print("\n✅ Successfully added continuumWidget target!")
    print("\nNext steps:")
    print("1. Open the project in Xcode")
    print("2. Clean the build folder (Product > Clean Build Folder)")
    print("3. Build the project")
    print("4. The widget should now appear when long-pressing the app icon")

if __name__ == '__main__':
    main()
