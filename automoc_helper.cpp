#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#if defined(_WIN32)
#include <windows.h>
#else
#include <dirent.h>
#include <sys/stat.h>
#endif
bool has_found=false;

void findMocJsonFiles(const std::string& path, const std::string& relativePath = "") {
    std::vector<std::string> files;
    std::vector<std::string> dirs;

    // Windows-specific directory reading
#if defined(_WIN32)
    WIN32_FIND_DATA findFileData;
    HANDLE hFind = FindFirstFile((path + "\\*").c_str(), &findFileData);

    if (hFind == INVALID_HANDLE_VALUE) {
        std::cerr << "Invalid file handle. Error is " << GetLastError() << std::endl;
        return;
    } else {
        do {
            const std::string fileOrDirName = findFileData.cFileName;
            if (!(findFileData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)) {
                files.push_back(fileOrDirName);
            } else if (fileOrDirName != "." && fileOrDirName != "..") {
                dirs.push_back(fileOrDirName);
            }
        } while (FindNextFile(hFind, &findFileData) != 0);
        FindClose(hFind);
    }
#else
    // POSIX-specific directory reading
    DIR *dir;
    struct dirent *ent;
    struct stat st;

    dir = opendir(path.c_str());
    if (dir == nullptr) {
        std::cerr << "Cannot open directory: " << path << std::endl;
        return;
    }

    while ((ent = readdir(dir)) != nullptr) {
        const std::string fileOrDirName = ent->d_name;
        const std::string fullPath = path + "/" + fileOrDirName;

        if (fileOrDirName[0] == '.') {
            continue;
        }

        if (stat(fullPath.c_str(), &st) == -1) {
            continue;
        }

        const bool isDirectory = (st.st_mode & S_IFDIR) != 0;

        if (isDirectory) {
            dirs.push_back(fileOrDirName);
        } else {
            files.push_back(fileOrDirName);
        }
    }
    closedir(dir);
#endif

    // Process files
    for (const auto& file : files) {
        if (file.rfind("moc", 0) == 0 && file.substr(file.length() - 5) == ".json") {
            if(!has_found)
                has_found = true;
            std::cout << relativePath + file << "\n";
        }
    }

    // Recursively process directories
    for (const auto& dir : dirs) {
        findMocJsonFiles(path + (path.back() == '/' || path.back() == '\\' ? "" : "/") + dir, relativePath + dir + "/");
    }
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " path_to_automoc_directory\n";
        return 1;
    }

    std::string startDirectory = argv[1];
    findMocJsonFiles(startDirectory, startDirectory + "/");
    if(!has_found){
        std::ofstream temp(startDirectory+"/blank.json");
        if(temp.is_open()){
            std::cout << startDirectory + "/blank.json";
            temp.close();
        }
        else{
            std::cout<<"Write temp file error!";
            return -1;
        }
    }
    std::cout << std::endl;
    return 0;
}
