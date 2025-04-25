/**
 * Project Separation Verification Script
 * 
 * This script checks for potential conflicts and dependencies between
 * the educational-chatbot and my-smart-teacher projects.
 */

const fs = require('fs');
const path = require('path');

// Project paths
const EDUCATIONAL_CHATBOT_PATH = path.join(__dirname, 'educational-chatbot');
const MY_SMART_TEACHER_PATH = path.join(__dirname, 'my-smart-teacher');
const MY_SMART_TEACHER_FRONTEND_PATH = path.join(MY_SMART_TEACHER_PATH, 'frontend');

// Check if a directory exists
function directoryExists(dirPath) {
  try {
    return fs.statSync(dirPath).isDirectory();
  } catch (err) {
    return false;
  }
}

// Check if both projects exist
function checkProjectsExist() {
  console.log('Checking if both projects exist...');
  
  const educationalChatbotExists = directoryExists(EDUCATIONAL_CHATBOT_PATH);
  const mySmartTeacherExists = directoryExists(MY_SMART_TEACHER_PATH);
  
  if (!educationalChatbotExists) {
    console.error('❌ educational-chatbot project not found!');
    return false;
  }
  
  if (!mySmartTeacherExists) {
    console.error('❌ my-smart-teacher project not found!');
    return false;
  }
  
  console.log('✅ Both projects exist.');
  return true;
}

// Read package.json and parse dependencies
function getDependencies(packageJsonPath) {
  try {
    const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
    return {
      dependencies: packageJson.dependencies || {},
      devDependencies: packageJson.devDependencies || {}
    };
  } catch (err) {
    console.error(`❌ Error reading ${packageJsonPath}: ${err.message}`);
    return { dependencies: {}, devDependencies: {} };
  }
}

// Compare dependencies between projects
function compareDependencies() {
  console.log('\nComparing dependencies between projects...');
  
  const educationalChatbotPackageJson = path.join(EDUCATIONAL_CHATBOT_PATH, 'package.json');
  const mySmartTeacherPackageJson = path.join(MY_SMART_TEACHER_FRONTEND_PATH, 'package.json');
  
  const educationalChatbotDeps = getDependencies(educationalChatbotPackageJson);
  const mySmartTeacherDeps = getDependencies(mySmartTeacherPackageJson);
  
  // Check for shared dependencies with different versions
  const sharedDependencies = [];
  const conflictingVersions = [];
  
  // Check regular dependencies
  for (const [dep, version] of Object.entries(educationalChatbotDeps.dependencies)) {
    if (mySmartTeacherDeps.dependencies[dep]) {
      sharedDependencies.push(dep);
      
      if (version !== mySmartTeacherDeps.dependencies[dep]) {
        conflictingVersions.push({
          name: dep,
          educationalChatbotVersion: version,
          mySmartTeacherVersion: mySmartTeacherDeps.dependencies[dep]
        });
      }
    }
  }
  
  // Check dev dependencies
  for (const [dep, version] of Object.entries(educationalChatbotDeps.devDependencies)) {
    if (mySmartTeacherDeps.devDependencies[dep]) {
      sharedDependencies.push(dep);
      
      if (version !== mySmartTeacherDeps.devDependencies[dep]) {
        conflictingVersions.push({
          name: dep,
          educationalChatbotVersion: version,
          mySmartTeacherVersion: mySmartTeacherDeps.devDependencies[dep]
        });
      }
    }
  }
  
  console.log(`Found ${sharedDependencies.length} shared dependencies.`);
  
  if (conflictingVersions.length > 0) {
    console.warn('⚠️ Found dependencies with conflicting versions:');
    conflictingVersions.forEach(conflict => {
      console.warn(`  - ${conflict.name}: educational-chatbot (${conflict.educationalChatbotVersion}) vs my-smart-teacher (${conflict.mySmartTeacherVersion})`);
    });
  } else {
    console.log('✅ No conflicting dependency versions found.');
  }
  
  return { sharedDependencies, conflictingVersions };
}

// Check for duplicate component names
function checkDuplicateComponents() {
  console.log('\nChecking for duplicate component names...');
  
  const educationalChatbotComponentsDir = path.join(EDUCATIONAL_CHATBOT_PATH, 'src', 'components');
  const mySmartTeacherComponentsDir = path.join(MY_SMART_TEACHER_FRONTEND_PATH, 'src', 'components');
  
  if (!directoryExists(educationalChatbotComponentsDir) || !directoryExists(mySmartTeacherComponentsDir)) {
    console.error('❌ Components directories not found!');
    return { duplicateComponents: [] };
  }
  
  // Get all component files from educational-chatbot
  const educationalChatbotComponents = fs.readdirSync(educationalChatbotComponentsDir)
    .filter(file => file.endsWith('.js') || file.endsWith('.jsx'))
    .map(file => path.basename(file, path.extname(file)));
  
  // Get all component files from my-smart-teacher (recursive)
  const mySmartTeacherComponents = [];
  
  function getComponentsRecursively(dir) {
    const files = fs.readdirSync(dir);
    
    files.forEach(file => {
      const filePath = path.join(dir, file);
      const stat = fs.statSync(filePath);
      
      if (stat.isDirectory()) {
        getComponentsRecursively(filePath);
      } else if (file.endsWith('.tsx') || file.endsWith('.jsx') || file.endsWith('.js')) {
        mySmartTeacherComponents.push(path.basename(file, path.extname(file)));
      }
    });
  }
  
  try {
    getComponentsRecursively(mySmartTeacherComponentsDir);
  } catch (err) {
    console.error(`❌ Error reading components: ${err.message}`);
  }
  
  // Find duplicates
  const duplicateComponents = educationalChatbotComponents.filter(component => 
    mySmartTeacherComponents.includes(component)
  );
  
  if (duplicateComponents.length > 0) {
    console.warn('⚠️ Found duplicate component names:');
    duplicateComponents.forEach(component => {
      console.warn(`  - ${component}`);
    });
  } else {
    console.log('✅ No duplicate component names found.');
  }
  
  return { duplicateComponents };
}

// Check for port conflicts in development scripts
function checkPortConflicts() {
  console.log('\nChecking for port conflicts in development scripts...');
  
  const educationalChatbotPackageJson = path.join(EDUCATIONAL_CHATBOT_PATH, 'package.json');
  const mySmartTeacherPackageJson = path.join(MY_SMART_TEACHER_FRONTEND_PATH, 'package.json');
  
  try {
    const educationalChatbotConfig = JSON.parse(fs.readFileSync(educationalChatbotPackageJson, 'utf8'));
    const mySmartTeacherConfig = JSON.parse(fs.readFileSync(mySmartTeacherPackageJson, 'utf8'));
    
    const educationalChatbotStartScript = educationalChatbotConfig.scripts?.start || '';
    const mySmartTeacherStartScript = mySmartTeacherConfig.scripts?.dev || mySmartTeacherConfig.scripts?.start || '';
    
    // Check for port specifications in start scripts
    const educationalChatbotPort = educationalChatbotStartScript.match(/--port\s+(\d+)/)?.[1] || '3000'; // Default CRA port
    const mySmartTeacherPort = mySmartTeacherStartScript.match(/--port\s+(\d+)/)?.[1] || '5173'; // Default Vite port
    
    if (educationalChatbotPort === mySmartTeacherPort) {
      console.warn(`⚠️ Port conflict detected! Both projects may try to use port ${educationalChatbotPort}.`);
      return { hasConflict: true, port: educationalChatbotPort };
    } else {
      console.log(`✅ No port conflicts detected. educational-chatbot uses port ${educationalChatbotPort}, my-smart-teacher uses port ${mySmartTeacherPort}.`);
      return { hasConflict: false };
    }
  } catch (err) {
    console.error(`❌ Error checking port conflicts: ${err.message}`);
    return { hasConflict: false };
  }
}

// Generate recommendations based on findings
function generateRecommendations(results) {
  console.log('\n=== RECOMMENDATIONS ===');
  
  if (results.conflictingVersions.length > 0) {
    console.log('\n1. Dependency Version Conflicts:');
    console.log('   Consider aligning dependency versions between projects or ensuring they work independently.');
    console.log('   Conflicting dependencies:');
    results.conflictingVersions.forEach(conflict => {
      console.log(`   - ${conflict.name}`);
    });
  }
  
  if (results.duplicateComponents.length > 0) {
    console.log('\n2. Duplicate Component Names:');
    console.log('   Rename components in one of the projects to avoid confusion:');
    results.duplicateComponents.forEach(component => {
      console.log(`   - ${component} → Consider renaming to Project${component}`);
    });
  }
  
  if (results.portConflict.hasConflict) {
    console.log('\n3. Development Port Conflict:');
    console.log(`   Both projects are trying to use port ${results.portConflict.port}.`);
    console.log('   Update one project\'s start script to use a different port:');
    console.log('   - For educational-chatbot: "start": "PORT=3000 react-scripts start"');
    console.log('   - For my-smart-teacher: "dev": "vite --port 5173"');
  }
  
  console.log('\n4. General Recommendations:');
  console.log('   - Keep README files updated with clear project purposes');
  console.log('   - Consider creating a monorepo structure if both projects will continue to be developed');
  console.log('   - Document any shared backend services or APIs');
  console.log('   - Create separate deployment pipelines for each project');
}

// Main function
function main() {
  console.log('=== PROJECT SEPARATION VERIFICATION ===\n');
  
  if (!checkProjectsExist()) {
    return;
  }
  
  const { sharedDependencies, conflictingVersions } = compareDependencies();
  const { duplicateComponents } = checkDuplicateComponents();
  const portConflict = checkPortConflicts();
  
  const results = {
    sharedDependencies,
    conflictingVersions,
    duplicateComponents,
    portConflict
  };
  
  generateRecommendations(results);
  
  console.log('\n=== VERIFICATION COMPLETE ===');
}

// Run the script
main();