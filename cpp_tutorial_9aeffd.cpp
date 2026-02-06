// LEARNING OBJECTIVE: This tutorial demonstrates how to visualize the hierarchical structure of running processes on your system using C++ and platform-specific APIs.
// We will focus on retrieving process information and understanding parent-child relationships to build this visualization.
// This example will cover the Linux/macOS platform. A Windows version would require different APIs.

#include <iostream>
#include <vector>
#include <string>
#include <fstream> // For reading /proc/ processes
#include <sstream> // For parsing strings
#include <algorithm> // For sorting

// Forward declaration of a struct to hold process information
struct ProcessInfo {
    int pid;       // The process ID
    int ppid;      // The parent process ID
    std::string name; // The name of the process
    int level;     // The depth in the process hierarchy, used for indentation
};

// Function to get process information from the /proc filesystem (Linux/macOS)
// The /proc filesystem provides a way to access kernel and process information.
// Each directory named with a PID represents a running process.
std::vector<ProcessInfo> getAllProcessInfo() {
    std::vector<ProcessInfo> processes; // Vector to store all gathered process information

    // We'll iterate through all directories in /proc that are numeric (representing PIDs)
    // For each PID, we'll try to read its status file to get PPID and name.
    DIR* dir = opendir("/proc"); // Open the /proc directory
    if (!dir) {
        std::cerr << "Error: Could not open /proc directory." << std::endl;
        return processes; // Return an empty vector if /proc cannot be opened
    }

    struct dirent* entry; // Structure to hold directory entry information
    while ((entry = readdir(dir)) != nullptr) {
        // Check if the directory name is a number (potential PID)
        if (entry->d_type == DT_DIR && std::all_of(entry->d_name, entry->d_name + strlen(entry->d_name), ::isdigit)) {
            int pid = std::stoi(entry->d_name); // Convert the directory name to an integer PID
            std::string stat_path = std::string("/proc/") + entry->d_name + "/stat"; // Construct the path to the stat file

            std::ifstream stat_file(stat_path); // Open the stat file for the process
            if (stat_file.is_open()) {
                std::string line;
                std::getline(stat_file, line); // Read the entire line from the stat file

                std::stringstream ss(line); // Use stringstream to easily parse the line
                int current_pid;
                char open_paren, close_paren; // To capture '(' and ')' around process name
                std::string comm; // Command name
                int ppid; // Parent Process ID
                int state; // Process state

                // The /proc/<pid>/stat file has a specific format. We need to extract PID, command name, and PPID.
                // The format is roughly: PID (COMM) STATE PPID ...
                // We skip several fields to reach PPID.
                ss >> current_pid >> open_paren >> comm >> close_paren >> state >> ppid;

                // Ensure the PID we read from stat matches the directory name (sanity check)
                if (current_pid == pid) {
                    ProcessInfo info;
                    info.pid = pid;
                    info.ppid = ppid;
                    info.name = comm;
                    info.level = 0; // Initialize level to 0, will be calculated later
                    processes.push_back(info); // Add the process info to our vector
                }
            }
            stat_file.close(); // Close the stat file
        }
    }
    closedir(dir); // Close the /proc directory
    return processes; // Return the vector of process information
}

// Function to build and print the hierarchical process tree
// This function uses recursion to traverse the parent-child relationships.
void printProcessTree(const std::vector<ProcessInfo>& all_processes, int current_pid, int level) {
    // Find all direct children of the current process
    std::vector<const ProcessInfo*> children;
    for (const auto& proc : all_processes) {
        if (proc.ppid == current_pid) {
            children.push_back(&proc); // Add child to the list
        }
    }

    // Sort children by PID for consistent output
    std::sort(children.begin(), children.end(), [](const ProcessInfo* a, const ProcessInfo* b) {
        return a->pid < b->pid;
    });

    // Print each child with appropriate indentation
    for (const auto& child : children) {
        // Print indentation based on the level in the hierarchy
        for (int i = 0; i < level; ++i) {
            std::cout << "  "; // Two spaces per level for indentation
        }
        // Print the process information: PID, PPID, and Name
        std::cout << "+-- " << child->name << " (PID: " << child->pid << ", PPID: " << child->ppid << ")" << std::endl;

        // Recursively call to print the children of this child
        printProcessTree(all_processes, child->pid, level + 1);
    }
}

int main() {
    // Objective: To visualize the parent-child relationship of running processes.
    // We'll achieve this by:
    // 1. Fetching information for all running processes (PID, PPID, Name).
    // 2. Building a tree-like structure using the PPID as the parent link.
    // 3. Printing this structure with indentation to represent the hierarchy.

    std::cout << "Gathering process information..." << std::endl;
    std::vector<ProcessInfo> all_processes = getAllProcessInfo(); // Get information for all processes

    if (all_processes.empty()) {
        std::cerr << "No process information retrieved. This might happen on non-Linux/macOS systems or due to permissions." << std::endl;
        return 1; // Exit with an error code
    }

    std::cout << "Building and printing process tree..." << std::endl;
    std::cout << "Root (System) (PID: 0, PPID: 0)" << std::endl; // The initial "root" of the tree is often considered PID 0 (kernel) or PID 1 (init/systemd)
    printProcessTree(all_processes, 0, 0); // Start printing the tree from PID 0 (which is the kernel or init process's parent)

    return 0; // Indicate successful execution
}