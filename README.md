# Windows 用户环境变量清理脚本

![image](https://github.com/user-attachments/assets/2358782d-2c24-46b1-af01-5740663be45c)


这是一个 PowerShell 脚本，用于扫描当前 Windows 用户账户的环境变量，检测其中指向不存在的文件系统目录的路径，并允许用户选择性地移除这些无效路径。

## 功能

1.  扫描当前用户的所有环境变量。
2.  识别看起来像文件系统路径（包含路径分隔符或以驱动器盘符开头，且不是网址）但实际不存在的目录。
3.  在终端中列出所有发现的无效目录及其对应的环境变量，并进行编号。
4.  根据用户输入，允许删除指定的无效路径（对于 PATH 等多路径变量）或删除包含无效路径的整个环境变量（对于单值变量）。

## 如何使用

1.  将脚本代码保存到一个 `.ps1` 文件中，例如 `clean_env.ps1`。
2.  打开 PowerShell 终端。
3.  使用 `cd` 命令切换到你保存脚本的目录。
    ```powershell
    cd /你的/脚本/目录
    ```
4.  运行脚本：
    ```powershell
    .\clean_env.ps1
    ```

### 关于 PowerShell 执行策略

如果运行脚本时遇到错误，提示脚本无法运行，这可能是由于 PowerShell 的执行策略限制。你可以选择以下方法之一来解决：

*   **临时允许运行本地脚本（推荐）：**
    打开一个**管理员身份**的 PowerShell 终端，运行以下命令：
    ```powershell
    Set-ExecutionPolicy RemoteSigned -Scope Process
    ```
    这只在当前终端会话中有效。然后回到你自己的用户终端运行脚本。
*   **更改当前用户的执行策略：**
    在管理员身份的 PowerShell 中运行：
    ```powershell
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
    ```
    这将永久更改当前用户的执行策略，允许运行本地脚本。请注意潜在的安全风险。

5.  脚本会列出发现的无效路径。根据提示输入要删除的序号（用逗号分隔），或者输入 `all` 删除全部，输入 `q` 退出。
6.  输入 `yes` 确认删除操作。

## 注意事项

*   **只处理用户环境变量：** 脚本只扫描和修改当前用户的环境变量，不会影响系统环境变量。
*   **Path 变量的特殊处理：** 对于 `Path` 等包含多个路径的环境变量，脚本会尝试只移除用户指定的不存在的路径，保留其他路径。
*   **其他变量的处理：** 对于其他单值环境变量，如果其值被识别为不存在的目录并被用户选择删除，脚本会删除整个环境变量。
*   **重启生效：** 修改环境变量后，可能需要重新启动应用程序或计算机，以使更改生效。
*   **非路径字符串的识别：** 脚本尝试识别并忽略非文件系统路径的字符串（如网址）。虽然采用了一些启发式规则，但可能无法完全精确，请仔细核对脚本列出的信息。

在使用前请仔细阅读并理解脚本的功能。如有疑问，请随时提出。 
