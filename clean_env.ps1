# 自动清理Windows用户环境变量脚本

Write-Host "正在扫描用户环境变量，请稍候..."

$notFoundPaths = @()
# 修改这里，只获取用户级别的环境变量
$userEnvVariables = [System.Environment]::GetEnvironmentVariables("User")

# 遍历用户环境变量
foreach ($variableName in $userEnvVariables.Keys) {
    $variableValue = $userEnvVariables[$variableName]

    # 仅处理Value是非空的字符串类型环境变量
    if ($variableValue -is [string] -and -not [string]::IsNullOrEmpty($variableValue)) {

        # 对于PATH这样的变量，其值可能包含多个路径，用分号分隔
        # 这里我们检查变量名是否为Path，或者其值是否包含分号，初步判断是否为多路径变量
        if ($variableName -ceq 'Path' -or $variableValue.Contains(';')) {
            $paths = $variableValue -split ';'
        } else {
            # 对于非多路径变量，我们将其整个值视为一个潜在路径
            $paths = @($variableValue)
        }

        foreach ($path in $paths) {
            $trimmedPath = $path.Trim()
            # 检查路径是否非空且似乎是一个文件系统路径
            # 我们只关注不存在的目录。
            if (-not [string]::IsNullOrEmpty($trimmedPath) -and -not (Test-Path -Path $trimmedPath -PathType Container) -and -not (Test-Path -Path $trimmedPath -PathType Leaf)) {
                 # 路径非空，且不是存在的目录也不是存在的文件，我们认为它是需要检查的目录且不存在
                 # 记录变量名和不存在的路径
                 # 避免重复添加同一个变量名和路径的组合
                 $exists = $false
                 foreach ($item in $notFoundPaths) {
                     # 这里我们检查变量名和具体的路径，因为一个变量（如Path）可能有多个不存在的路径
                     if ($item.VariableName -ceq $variableName -and $item.Path -ceq $trimmedPath) {
                         $exists = $true
                         break
                     }
                 }
                 if (-not $exists) {
                    $notFoundPaths += [PSCustomObject]@{
                         VariableName = $variableName
                         Path = $trimmedPath
                    }
                 }
            }
        }
    }
}

if ($notFoundPaths.Count -eq 0) {
    Write-Host "没有发现指向不存在目录的用户环境变量。"
} else {
    Write-Host "`n发现以下用户环境变量指向不存在的目录："
    for ($i = 0; $i -lt $notFoundPaths.Count; $i++) {
        Write-Host "$($i + 1). 变量名: $($notFoundPaths[$i].VariableName), 指向路径: $($notFoundPaths[$i].Path)"
    }

    Write-Host "`n请选择要删除的环境变量序号（多个序号用逗号分隔，如 1,3,5），输入 'all' 删除全部，输入 'q' 退出："

    $userInput = Read-Host "您的选择"

    if ($userInput -ceq 'q') {
        Write-Host "已退出，未做任何修改。"
    } elseif ($userInput -ceq 'all') {
        Write-Host "警告：你选择了删除所有列出的条目。对于Path等变量，这将移除其中所有列出的不存在路径；对于其他变量，将删除整个变量。请确认！"
        $confirm = Read-Host "输入 'yes' 确认删除，其他输入取消"
        if ($confirm -ceq 'yes') {
            # 将要删除的条目按变量名分组
            $itemsToDeleteGrouped = $notFoundPaths | Group-Object VariableName

            foreach ($group in $itemsToDeleteGrouped) {
                $variableName = $group.Name
                $itemsInGroup = $group.Group

                Write-Host "正在处理变量: $($variableName)"

                # 获取当前环境变量的实际值
                $currentVariableValue = [System.Environment]::GetEnvironmentVariable($variableName, "User")

                if ($null -ne $currentVariableValue -and $currentVariableValue -is [string]) {

                    # 对于Path或包含分号的变量，按路径处理
                    if ($variableName -ceq 'Path' -or $currentVariableValue.Contains(';')) {
                        $currentPaths = $currentVariableValue -split ';'
                        $pathsToRemove = $itemsInGroup | Select-Object -ExpandProperty Path
                        $newPaths = @()

                        foreach ($currentPath in $currentPaths) {
                            $trimmedCurrentPath = $currentPath.Trim()
                            $shouldRemove = $false
                            foreach ($pathToRemove in $pathsToRemove) {
                                # 忽略大小写比较路径
                                if ($trimmedCurrentPath -ceq $pathToRemove.Trim()) {
                                    $shouldRemove = $true
                                    Write-Host "- 移除不存在的路径: $($currentPath)"
                                    break
                                }
                            }
                            if (-not $shouldRemove -and -not [string]::IsNullOrEmpty($currentPath)) {
                                $newPaths += $currentPath # 保留存在的路径
                            }
                        }

                        # 更新环境变量
                        $newVariableValue = $newPaths -join ';'
                         # 只有当新旧值不同时才更新，避免不必要的修改
                        if ($newVariableValue -ceq $currentVariableValue) {
                             Write-Host "变量 $($variableName) 的值没有变化，无需更新。"
                        } else {
                             [System.Environment]::SetEnvironmentVariable($variableName, $newVariableValue, "User")
                             Write-Host "已更新变量: $($variableName)"
                        }

                    } else {
                        # 对于其他变量，如果被列出（意味着整个值被认为是无效路径），则删除整个变量
                         Write-Host "- 删除整个变量: $($variableName) (指向路径: $($itemsInGroup[0].Path))"
                        [System.Environment]::SetEnvironmentVariable($variableName, $null, "User")
                        Write-Host "已删除变量: $($variableName)"
                    }
                }
            }
            Write-Host "所有列出的环境变量条目已处理。"
        } else {
            Write-Host "已取消删除操作。"
        }
    } else {
        try {
            $indicesToDelete = $userInput.Split(',') | ForEach-Object { ([int]$_.Trim()) - 1 } | Where-Object { $_ -ge 0 -and $_ -lt $notFoundPaths.Count }
            if ($indicesToDelete.Count -gt 0) {
                 Write-Host "即将处理以下环境变量条目："
                 # 将用户选择的序号对应的条目按变量名分组
                 $selectedItemsGrouped = $indicesToDelete | ForEach-Object { $notFoundPaths[$_] } | Group-Object VariableName

                 foreach ($group in $selectedItemsGrouped) {
                    $variableName = $group.Name
                    $itemsInGroup = $group.Group # 用户选择的要移除的路径/条目列表

                    Write-Host "- 变量 $($variableName) 的以下路径将被移除："
                    foreach ($item in $itemsInGroup) {
                        Write-Host "  - $($item.Path)"
                    }
                 }

                 $confirm = Read-Host "输入 'yes' 确认执行上述操作，其他输入取消"

                 if ($confirm -ceq 'yes') {
                     foreach ($group in $selectedItemsGrouped) {
                        $variableName = $group.Name
                        $itemsInGroup = $group.Group

                        Write-Host "正在处理变量: $($variableName)"

                        # 获取当前环境变量的实际值
                        $currentVariableValue = [System.Environment]::GetEnvironmentVariable($variableName, "User")

                         if ($null -ne $currentVariableValue -and $currentVariableValue -is [string]) {

                            # 对于Path或包含分号的变量，按路径处理
                            if ($variableName -ceq 'Path' -or $currentVariableValue.Contains(';')) {
                                $currentPaths = $currentVariableValue -split ';'
                                $pathsToRemove = $itemsInGroup | Select-Object -ExpandProperty Path
                                $newPaths = @()

                                foreach ($currentPath in $currentPaths) {
                                    $trimmedCurrentPath = $currentPath.Trim()
                                    $shouldRemove = $false
                                    foreach ($pathToRemove in $pathsToRemove) {
                                        # 忽略大小写比较路径
                                        if ($trimmedCurrentPath -ceq $pathToRemove.Trim()) {
                                            $shouldRemove = $true
                                            break
                                        }
                                    }
                                    if (-not $shouldRemove -and -not [string]::IsNullOrEmpty($currentPath)) {
                                        $newPaths += $currentPath # 保留存在的路径
                                    }
                                }

                                # 更新环境变量
                                $newVariableValue = $newPaths -join ';'
                                # 只有当新旧值不同时才更新，避免不必要的修改
                                if ($newVariableValue -ceq $currentVariableValue) {
                                     Write-Host "变量 $($variableName) 的值没有变化，无需更新。"
                                } else {
                                     [System.Environment]::SetEnvironmentVariable($variableName, $newVariableValue, "User")
                                     Write-Host "已更新变量: $($variableName)"
                                }

                            } else {
                                # 对于其他变量，如果其对应的条目被用户选择删除，则删除整个变量
                                Write-Host "删除整个变量: $($variableName)"
                                [System.Environment]::SetEnvironmentVariable($variableName, $null, "User")
                                Write-Host "已删除变量: $($variableName)"
                            }
                         }
                     }
                    Write-Host "指定的环境变量条目已处理。"
                 } else {
                     Write-Host "已取消删除操作。"
                 }

            } else {
                Write-Host "无效的输入或序号，未做任何修改。"
            }
        } catch {
            Write-Host "输入格式错误，未做任何修改。请确保输入的是数字序号或 'all' 或 'q'。"
        }
    }
}

Write-Host "`n脚本运行结束。"
