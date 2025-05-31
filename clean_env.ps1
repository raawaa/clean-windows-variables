# 自动清理Windows用户环境变量脚本

Write-Host "正在扫描用户环境变量，请稍候..."

$notFoundPaths = @()
$envVariables = Get-ChildItem Env:

foreach ($envVar in $envVariables) {
    # 仅处理Value是非空的字符串类型环境变量
    if ($envVar.Value -is [string] -and -not [string]::IsNullOrEmpty($envVar.Value)) {
        $variableName = $envVar.Name
        $variableValue = $envVar.Value

        # 对于PATH这样的变量，其值可能包含多个路径，用分号分隔
        $paths = $variableValue -split ';'

        foreach ($path in $paths) {
            $trimmedPath = $path.Trim()
            # 检查路径是否非空且似乎是一个文件系统路径
            if (-not [string]::IsNullOrEmpty($trimmedPath) -and (Test-Path -Path $trimmedPath -PathType Container)) {
                # 路径存在，不做处理
            } elseif (-not [string]::IsNullOrEmpty($trimmedPath) -and -not (Test-Path -Path $trimmedPath -PathType Container) -and -not (Test-Path -Path $trimmedPath -PathType Leaf)) {
                 # 路径非空，且不是存在的目录也不是存在的文件，我们认为它是需要检查的目录且不存在
                 # 记录变量名和不存在的路径
                 # 避免重复添加同一个变量名和路径的组合
                 $exists = $false
                 foreach ($item in $notFoundPaths) {
                     if ($item.VariableName -eq $variableName -and $item.Path -eq $trimmedPath) {
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
        Write-Host "警告：即将删除所有列出的环境变量。请确认！"
        $confirm = Read-Host "输入 'yes' 确认删除，其他输入取消"
        if ($confirm -ceq 'yes') {
            foreach ($item in $notFoundPaths) {
                Write-Host "正在删除变量: $($item.VariableName)"
                # 注意：这里我们删除整个环境变量，而不是修改它的值来移除不存在的路径
                # 因为修改PATH变量值比较复杂，需要处理多个路径，容易出错
                # 删除整个变量是最直接的方式。用户之后可以手动重新添加正确的变量。
                # 如果需要精确修改PATH，脚本会复杂很多。为了简洁和安全，选择删除整个变量。
                [System.Environment]::SetEnvironmentVariable($item.VariableName, $null, "User")
                Write-Host "已删除变量: $($item.VariableName)"
            }
            Write-Host "所有列出的环境变量已删除。"
        } else {
            Write-Host "已取消删除操作。"
        }
    } else {
        try {
            $indicesToDelete = $userInput.Split(',') | ForEach-Object { ([int]$_.Trim()) - 1 } | Where-Object { $_ -ge 0 -and $_ -lt $notFoundPaths.Count }
            if ($indicesToDelete.Count -gt 0) {
                 Write-Host "即将删除以下环境变量："
                 foreach ($index in $indicesToDelete) {
                     Write-Host "- 变量名: $($notFoundPaths[$index].VariableName), 指向路径: $($notFoundPaths[$index].Path)"
                 }
                 $confirm = Read-Host "输入 'yes' 确认删除，其他输入取消"
                 if ($confirm -ceq 'yes') {
                     foreach ($index in $indicesToDelete) {
                         $item = $notFoundPaths[$index]
                         Write-Host "正在删除变量: $($item.VariableName)"
                         [System.Environment]::SetEnvironmentVariable($item.VariableName, $null, "User")
                         Write-Host "已删除变量: $($item.VariableName)"
                     }
                     Write-Host "指定的环境变量已删除。"
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
