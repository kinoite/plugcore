local M = {}

M.install_base_path = vim.fn.stdpath('data') .. '/site/pack/plugins'
M.db_base_path = vim.fn.stdpath('data') .. '/plugcore/db'

M.blueprint_repos = {
    { url = 'https://github.com/kinoite/pc-community.git', name = 'community' },
}

M.plugins = {
    { name = 'nerdtree' },
    { name = 'vim-airline', version = '0.11' },
    { name = 'fugitive' },
}

local function execute_command(cmd)
    local f = io.popen(cmd)
    if not f then
        vim.notify('ERROR: Failed to run command: ' .. cmd, vim.log.levels.ERROR)
        return false
    end
    local output = f:read('*a')
    local status = f:close()

    if status then
        if #output > 0 and vim.log.levels.DEBUG >= (vim.log.levels.INFO or 0) then
             vim.notify('Command OK: ' .. cmd .. '\nOutput:\n' .. output, vim.log.levels.DEBUG)
        end
        return true
    else
        vim.notify('ERROR: Command failed: ' .. cmd .. '\nOutput:\n' .. output, vim.log.levels.ERROR)
        return false
    end
end

local function delete_directory(path)
    if vim.fn.isdirectory(path) == 0 then
        vim.notify('Directory does not exist for deletion: ' .. path, vim.log.levels.INFO)
        return true
    end
    vim.notify('Deleting directory: ' .. path, vim.log.levels.INFO)
    local cmd = string.format('rm -rf %s', vim.fn.shellescape(path))
    return execute_command(cmd)
end

local function sync_blueprint_repo(repo_spec)
    local repo_url = repo_spec.url
    local repo_name = repo_spec.name
    local repo_dir = M.db_base_path .. '/' .. repo_name

    vim.notify('Synchronizing blueprint repo: ' .. repo_name .. ' from ' .. repo_url, vim.log.levels.INFO)

    if vim.fn.isdirectory(repo_dir) == 1 then
        vim.notify('Pulling changes for blueprint repo: ' .. repo_name, vim.log.levels.INFO)
        local cmd = string.format('cd %s && git pull', vim.fn.shellescape(repo_dir))
        if not execute_command(cmd) then
            vim.notify('ERROR: Failed to pull blueprint repo: ' .. repo_name, vim.log.levels.ERROR)
            return false
        end
    else
        vim.notify('Cloning blueprint repo: ' .. repo_name, vim.log.levels.INFO)
        local cmd = string.format('git clone %s %s', vim.fn.shellescape(repo_url), vim.fn.shellescape(repo_dir))
        if not execute_command(cmd) then
            vim.notify('ERROR: Failed to clone blueprint repo: ' .. repo_name, vim.log.levels.ERROR)
            return false
        end
    end
    vim.notify('Blueprint repo synchronized: ' .. repo_name, vim.log.levels.INFO)
    return true
end

local function execute_blueprint(plugin_name, version, action)
    local blueprint_path = M.db_base_path .. '/community/' .. plugin_name .. '.lua'

    if vim.fn.filereadable(blueprint_path) == 0 then
        vim.notify('ERROR: Blueprint not found for plugin: ' .. plugin_name .. ' at ' .. blueprint_path, vim.log.levels.ERROR)
        vim.notify('Did you run :PlugcoreSyncBlueprints?', vim.log.levels.INFO)
        return false
    end

    vim.notify('Executing blueprint for ' .. plugin_name .. ' (' .. action .. ') ' .. (version and 'v' .. version or 'latest'), vim.log.levels.INFO)

    local blueprint_args = {
        plugin_name = plugin_name,
        version = version,
        action = action,
        install_path = M.install_base_path .. '/start/' .. plugin_name,
        temp_path = vim.fn.stdpath('data') .. '/plugcore_temp',
        execute_command = execute_command,
        delete_directory = delete_directory,
        notify = vim.notify,
        isdirectory = vim.fn.isdirectory,
        shellescape = vim.fn.shellescape,
        mkdir = vim.fn.mkdir,
    }

    local blueprint_func, err = loadfile(blueprint_path)
    if not blueprint_func then
        vim.notify('ERROR: Failed to load blueprint ' .. plugin_name .. ': ' .. err, vim.log.levels.ERROR)
        return false
    end

    local success, blueprint_result = pcall(blueprint_func, blueprint_args)
    if not success then
        vim.notify('ERROR: Blueprint execution failed for ' .. plugin_name .. ': ' .. blueprint_result, vim.log.levels.ERROR)
        return false
    end

    if not blueprint_result then
        vim.notify('Blueprint for ' .. plugin_name .. ' reported failure.', vim.log.levels.ERROR)
        return false
    end

    vim.notify('Blueprint executed successfully for ' .. plugin_name, vim.log.levels.INFO)
    return true
end

local function install_plugin(plugin_spec)
    local plugin_name = plugin_spec.name
    local version = plugin_spec.version

    local plugin_dir = M.install_base_path .. '/start/' .. plugin_name
    if vim.fn.isdirectory(plugin_dir) == 1 then
        vim.notify('Plugin "' .. plugin_name .. '" is already installed. Use PlugcoreUpdate if needed.', vim.log.levels.INFO)
        return true
    end

    vim.notify('Initiating installation for ' .. plugin_name .. '...', vim.log.levels.INFO)
    return execute_blueprint(plugin_name, version, 'install')
end

local function update_plugin(plugin_spec)
    local plugin_name = plugin_spec.name
    local version = plugin_spec.version

    local plugin_dir = M.install_base_path .. '/start/' .. plugin_name
    if vim.fn.isdirectory(plugin_dir) == 0 then
        vim.notify('Plugin "' .. plugin_name .. '" not found for update. Installing instead.', vim.log.levels.INFO)
        return install_plugin(plugin_spec)
    end

    vim.notify('Initiating update for ' .. plugin_name .. '...', vim.log.levels.INFO)
    return execute_blueprint(plugin_name, version, 'update')
end

function M.sync_blueprints()
    vim.notify('Starting blueprint synchronization...', vim.log.levels.INFO)
    if vim.fn.isdirectory(M.db_base_path) == 0 then
        vim.fn.mkdir(M.db_base_path, 'p')
    end

    local success_count = 0
    for _, repo in ipairs(M.blueprint_repos) do
        if sync_blueprint_repo(repo) then
            success_count = success_count + 1
        end
    end
    if success_count == #M.blueprint_repos then
        vim.notify('All blueprint repositories synchronized successfully!', vim.log.levels.INFO)
    else
        vim.notify('WARNING: Some blueprint repositories failed to synchronize.', vim.log.levels.WARN)
    end
end

function M.install_plugins()
    vim.notify('Starting Plugcore plugin installation...', vim.log.levels.INFO)
    if vim.fn.isdirectory(M.install_base_path .. '/start') == 0 then
        vim.fn.mkdir(M.install_base_path .. '/start', 'p')
    end
    if vim.fn.isdirectory(M.install_base_path .. '/opt') == 0 then
        vim.fn.mkdir(M.install_base_path .. '/opt', 'p')
    end
    if vim.fn.isdirectory(vim.fn.stdpath('data') .. '/plugcore_temp') == 0 then
        vim.fn.mkdir(vim.fn.stdpath('data') .. '/plugcore_temp', 'p')
    end

    local install_count = 0
    for _, plugin_spec in ipairs(M.plugins) do
        if install_plugin(plugin_spec) then
            install_count = install_count + 1
        end
    end
    vim.notify('Plugcore installation complete. Installed ' .. install_count .. ' plugins.', vim.log.levels.INFO)
end

function M.update_plugins()
    vim.notify('Starting Plugcore plugin update...', vim.log.levels.INFO)
    local update_count = 0
    for _, plugin_spec in ipairs(M.plugins) do
        if update_plugin(plugin_spec) then
            update_count = update_count + 1
        end
    end
    vim.notify('Plugcore update complete. Updated ' .. update_count .. ' plugins.', vim.log.levels.INFO)
end

function M.clean_plugins()
    vim.notify('Starting Plugcore plugin cleanup...', vim.log.levels.INFO)

    local installed_plugins = {}
    local start_dir = M.install_base_path .. '/start'
    if vim.fn.isdirectory(start_dir) == 1 then
        for _, entry in ipairs(vim.fn.readdir(start_dir)) do
            if entry ~= '.' and entry ~= '..' then
                table.insert(installed_plugins, entry)
            end
        end
    end

    local plugins_to_keep = {}
    for _, plugin_spec in ipairs(M.plugins) do
        plugins_to_keep[plugin_spec.name] = true
    end

    local cleaned_count = 0
    for _, installed_name in ipairs(installed_plugins) do
        if not plugins_to_keep[installed_name] then
            local full_path = start_dir .. '/' .. installed_name
            vim.notify('Found unused plugin: ' .. installed_name .. '. Deleting...', vim.log.levels.WARN)
            -- if vim.fn.confirm('Delete unused plugin: ' .. installed_name .. '?', '&Yes\n&No', 2) == 1 then
                if delete_directory(full_path) then
                    vim.notify('Deleted unused plugin: ' .. installed_name, vim.log.levels.INFO)
                    cleaned_count = cleaned_count + 1
                else
                    vim.notify('ERROR: Could not delete unused plugin: ' .. installed_name, vim.log.levels.ERROR)
                end
            -- else
            --     vim.notify('Skipped deletion of ' .. installed_name, vim.log.levels.INFO)
            -- end
        end
    end
    vim.notify('Plugcore plugin cleanup complete. Removed ' .. cleaned_count .. ' unused plugins.', vim.log.levels.INFO)
end

vim.api.nvim_create_user_command('PlugcoreInstall', M.install_plugins, { nargs = 0, desc = 'Install configured plugins via Plugcore' })
vim.api.nvim_create_user_command('PlugcoreUpdate', M.update_plugins, { nargs = 0, desc = 'Update configured plugins via Plugcore' })
vim.api.nvim_create_user_command('PlugcoreClean', M.clean_plugins, { nargs = 0, desc = 'Clean up unused plugins via Plugcore' })
vim.api.nvim_create_user_command('PlugcoreSyncBlueprints', M.sync_blueprints, { nargs = 0, desc = 'Synchronize Plugcore blueprint repositories' })

return M
