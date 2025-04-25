/**
 * Run Projects Script
 * 
 * This script helps run both educational-chatbot and my-smart-teacher projects
 * simultaneously without port conflicts.
 */

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const readline = require('readline');

// Project paths
const EDUCATIONAL_CHATBOT_PATH = path.join(__dirname, 'educational-chatbot');
const MY_SMART_TEACHER_FRONTEND_PATH = path.join(__dirname, 'my-smart-teacher', 'frontend');

// Colors for console output
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m'
};

// Check if a directory exists
function directoryExists(dirPath) {
  try {
    return fs.statSync(dirPath).isDirectory();
  } catch (err) {
    return false;
  }
}

// Print colored message
function printColored(message, color) {
  console.log(`${color}${message}${colors.reset}`);
}

// Run a command in a specific directory
function runCommand(command, args, cwd, name, color) {
  return new Promise((resolve, reject) => {
    printColored(`Starting ${name}...`, color);
    
    const process = spawn(command, args, {
      cwd,
      shell: true,
      stdio: 'pipe'
    });
    
    // Handle stdout
    process.stdout.on('data', (data) => {
      const lines = data.toString().trim().split('\n');
      lines.forEach(line => {
        if (line.trim()) {
          console.log(`${color}[${name}] ${line}${colors.reset}`);
        }
      });
    });
    
    // Handle stderr
    process.stderr.on('data', (data) => {
      const lines = data.toString().trim().split('\n');
      lines.forEach(line => {
        if (line.trim()) {
          console.log(`${color}[${name} ERROR] ${line}${colors.reset}`);
        }
      });
    });
    
    // Handle process exit
    process.on('close', (code) => {
      if (code === 0) {
        printColored(`${name} exited successfully.`, color);
        resolve();
      } else {
        printColored(`${name} exited with code ${code}.`, colors.red);
        reject(new Error(`${name} exited with code ${code}`));
      }
    });
    
    // Handle process error
    process.on('error', (err) => {
      printColored(`Error starting ${name}: ${err.message}`, colors.red);
      reject(err);
    });
    
    return process;
  });
}

// Check and update port settings if needed
function checkAndUpdatePorts() {
  printColored('Checking port configurations...', colors.cyan);
  
  try {
    // Check educational-chatbot port
    const educationalChatbotPackagePath = path.join(EDUCATIONAL_CHATBOT_PATH, 'package.json');
    const educationalChatbotPackage = JSON.parse(fs.readFileSync(educationalChatbotPackagePath, 'utf8'));
    
    // Check my-smart-teacher port
    const mySmartTeacherPackagePath = path.join(MY_SMART_TEACHER_FRONTEND_PATH, 'package.json');
    const mySmartTeacherPackage = JSON.parse(fs.readFileSync(mySmartTeacherPackagePath, 'utf8'));
    
    // Set default ports if not specified
    const educationalChatbotPort = 3000; // Default CRA port
    const mySmartTeacherPort = 5173;     // Default Vite port
    
    printColored(`Educational Chatbot will run on port ${educationalChatbotPort}`, colors.green);
    printColored(`My Smart Teacher will run on port ${mySmartTeacherPort}`, colors.green);
    
    return { educationalChatbotPort, mySmartTeacherPort };
  } catch (err) {
    printColored(`Error checking port configurations: ${err.message}`, colors.red);
    return { educationalChatbotPort: 3000, mySmartTeacherPort: 5173 };
  }
}

// Run both projects
async function runProjects() {
  printColored('=== RUNNING BOTH PROJECTS ===', colors.cyan);
  
  // Check if projects exist
  if (!directoryExists(EDUCATIONAL_CHATBOT_PATH)) {
    printColored('❌ educational-chatbot project not found!', colors.red);
    return;
  }
  
  if (!directoryExists(MY_SMART_TEACHER_FRONTEND_PATH)) {
    printColored('❌ my-smart-teacher frontend not found!', colors.red);
    return;
  }
  
  // Check and update port settings
  const { educationalChatbotPort, mySmartTeacherPort } = checkAndUpdatePorts();
  
  // Create readline interface for user input
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  
  // Start both projects
  try {
    // Start educational-chatbot
    const educationalChatbotProcess = runCommand(
      'npm',
      ['start'],
      EDUCATIONAL_CHATBOT_PATH,
      'Educational Chatbot',
      colors.blue
    );
    
    // Start my-smart-teacher frontend
    const mySmartTeacherProcess = runCommand(
      'npm',
      ['run', 'dev'],
      MY_SMART_TEACHER_FRONTEND_PATH,
      'My Smart Teacher',
      colors.magenta
    );
    
    printColored('\n=== PROJECTS RUNNING ===', colors.green);
    printColored(`Educational Chatbot: http://localhost:${educationalChatbotPort}`, colors.blue);
    printColored(`My Smart Teacher: http://localhost:${mySmartTeacherPort}`, colors.magenta);
    printColored('\nPress Ctrl+C to stop both projects.\n', colors.yellow);
    
    // Handle user input
    rl.on('line', (input) => {
      if (input.toLowerCase() === 'exit' || input.toLowerCase() === 'quit') {
        printColored('Stopping projects...', colors.yellow);
        process.exit(0);
      }
    });
    
    // Wait for both processes to complete (they won't unless terminated)
    await Promise.all([educationalChatbotProcess, mySmartTeacherProcess]);
  } catch (err) {
    printColored(`Error running projects: ${err.message}`, colors.red);
  } finally {
    rl.close();
  }
}

// Main function
function main() {
  runProjects().catch(err => {
    printColored(`Unhandled error: ${err.message}`, colors.red);
    process.exit(1);
  });
  
  // Handle SIGINT (Ctrl+C)
  process.on('SIGINT', () => {
    printColored('\nStopping projects...', colors.yellow);
    process.exit(0);
  });
}

// Run the script
main();