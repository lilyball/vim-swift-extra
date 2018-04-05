" File: unite/sources/swift.vim
" Author: Kevin Ballard
" Description: Unite sources file for Swift
" Last Change: Jul 12, 2015

let s:save_cpo = &cpo
set cpo&vim

function! unite#sources#swift#define() "{{{
    return [s:source_device, s:source_dev_dir, s:source_toolchain]
endfunction "}}}

" swift/device {{{

let s:source_device = {
            \ 'name': 'swift/device',
            \ 'hooks': {},
            \ 'action_table': {},
            \ 'syntax': 'uniteSource__SwiftDevice',
            \ 'default_action': 'set_global',
            \ 'description': 'iOS Simulator devices for use with Swift'
            \}

function! s:source_device.gather_candidates(args, context) "{{{
    let deviceInfo = swift#platform#simDeviceInfo()
    if empty(deviceInfo)
        redraw
        call unite#print_source_error('Error fetching sim device info', self.name)
        return []
    endif
    " sort devices into per-runtime buckets
    let runtimes = {}
    for item in deviceInfo.devices
        if has_key(runtimes, item.runtime.identifier)
            let runtime = runtimes[item.runtime.identifier]
        else
            let runtime = copy(item.runtime)
            let runtime.devices = []
            let runtimes[item.runtime.identifier] = runtime
        endif
        call add(runtime.devices, item)
    endfor
    " sort the buckets
    let runtimeList = sort(values(runtimes), "s:sort_runtime")
    for item in runtimeList
        call sort(item.devices, "s:sort_device")
    endfor
    " return each bucket as a list of devices
    let results = []
    for item in runtimeList
        call extend(results, map(item.devices, '{ ''word'': v:val.uuid, ''abbr'': v:val.name, ''group'': v:val.runtime.name }'))
    endfor
    return results
endfunction "}}}

function! s:source_device.hooks.on_post_filter(args, context) "{{{
    for candidate in a:context.candidates
        if get(candidate, 'is_dummy')
            " group name
            let candidate.abbr =
                        \ '-- ' . candidate.word . ' --'
        else
            let candidate.abbr =
                        \ '  ' . candidate.abbr . ' (' . candidate.group . ')'
        endif
    endfor
endfunction "}}}

function! s:source_device.hooks.on_syntax(args, context) "{{{
    syntax match uniteSource__SwiftDevice_Runtime /([^)]*)/
                \ contained containedin=uniteSource__SwiftDevice
    highlight default link uniteSource__SwiftDevice_Runtime Comment
endfunction "}}}

function! s:sort_runtime(a, b) "{{{
    let aName = s:first_word(a:a.name)
    let bName = s:first_word(a:b.name)
    if aName == bName
        " sort by number descending
        let aVersion = str2float(a:a.version)
        let bVersion = str2float(a:b.version)
        if aVersion < bVersion
            return 1
        elseif aVersion > bVersion
            return -1
        else
            return 0
        endif
    else
        " sort by name ascending
        if aName < bName
            return -1
        elseif aName > bName
            return 1
        else
            return 0
        endif
    endif
endfunction "}}}
function! s:sort_device(a, b) "{{{
    if a:a.name < a:b.name
        return -1
    elseif a:a.name > a:b.name
        return 1
    else
        return 0
    endif
endfunction "}}}
function! s:first_word(s) "{{{
    let space = stridx(a:s, " ")
    if space != -1
        return strpart(a:s, 0, space)
    else
        return a:s
    endif
endfunction "}}}

" Actions {{{

let s:source_device.action_table.set_buffer = {
            \ 'description': 'select the iOS Simulator device (buffer-local)',
            \ 'is_selectable': 0
            \}
function! s:source_device.action_table.set_buffer.func(candidate) "{{{
    let b:swift_device = a:candidate.word
endfunction "}}}

let s:source_device.action_table.set_global = {
            \ 'description': 'select the iOS Simulator device (global)',
            \ 'is_selectable': 0
            \}
function! s:source_device.action_table.set_global.func(candidate) "{{{
    let g:swift_device = a:candidate.word
endfunction "}}}

" }}}

" }}}
" swift/developer_dir {{{

let s:source_dev_dir = {
            \ 'name': 'swift/developer_dir',
            \ 'hooks': {},
            \ 'action_table': {},
            \ 'default_action': 'set_global',
            \ 'description': 'Xcode directories for use with Swift'
            \}

function! s:source_dev_dir.gather_candidates(args, context) "{{{
    if !swift#util#has_vimproc()
        call unite#print_source_message('vimproc plugin is not installed.', self.name)
        return []
    endif
    let cmd = swift#util#system('mdfind "kMDItemCFBundleIdentifier = com.apple.dt.Xcode"')
    if cmd.status == 0
        let result = [{'word': '', 'abbr': '(default)'}]
        call extend(result, map(cmd.output, "{ 'word': v:val }"))
        return result
    else
        call unite#print_source_error('mdfind error', self.name)
        for line in cmd.output
            call unite#print_source_error(line, self.name)
        endfor
        return []
    endif
endfunction "}}}

" Actions {{{

let s:source_dev_dir.action_table.set_buffer = {
            \ 'description': 'select the Swift developer dir (buffer-local)',
            \ 'is_selectable': 0
            \}
function! s:source_dev_dir.action_table.set_buffer.func(candidate) "{{{
    if empty(a:candidate.word)
        unlet! b:swift_developer_dir
    else
        let b:swift_developer_dir = a:candidate.word
    endif
endfunction "}}}

let s:source_dev_dir.action_table.set_global = {
            \ 'description': 'select the Swift developer dir (global)',
            \ 'is_selectable': 0
            \}
function! s:source_dev_dir.action_table.set_global.func(candidate) "{{{
    if empty(a:candidate.word)
        unlet! g:swift_developer_dir
    else
        let g:swift_developer_dir = a:candidate.word
    endif
endfunction "}}}

" }}}

" }}}
" swift/toolchain {{{

let s:source_toolchain = {
            \ 'name': 'swift/toolchain',
            \ 'hooks': {},
            \ 'action_table': {},
            \ 'syntax': 'uniteSource__SwiftToolchain',
            \ 'default_action': 'set_global',
            \ 'description': 'Xcode toolchains for use with Swift'
            \}

function! s:source_toolchain.gather_candidates(args, context) "{{{
    let result = [{ 'word': '' }]
    let paths = extend(
                \glob('/Library/Developer/Toolchains/*.xctoolchain', v:true, v:true),
                \glob('~/Library/Developer/Toolchains/*.xctoolchain', v:true, v:true)
                \)
    call extend(result, map(paths, funcref("s:toolchain_candidate_from_path")))
    return result
endfunction

function! s:toolchain_candidate_from_path(key, path)
    let l:candidate = { 'word': fnamemodify(a:path, ':t:r') }
    let l:result = swift#util#system(['/usr/libexec/PlistBuddy', '-c', 'Print DisplayName', a:path.'/Info.plist'])
    if l:result.status == 0 && !empty(l:result.output)
        if getftype(a:path) == 'link'
            let l:candidate.displayName = l:result.output[0]
        else
            let l:candidate.abbr = l:result.output[0]
        endif
    endif
    return l:candidate
endfunction "}}}

function! s:source_toolchain.hooks.on_post_filter(args, context) "{{{
    for candidate in a:context.candidates
        if !empty(get(candidate, 'displayName', ''))
            let candidate.abbr = '/' . candidate.word . ' ~(' . candidate.displayName . ')'
        elseif !empty(get(candidate, 'abbr', ''))
            let candidate.abbr = '~' . candidate.abbr
        else
            " this must be the default action
            let candidate.abbr = '/~(default)'
        endif
    endfor
endfunction "}}}

function! s:source_toolchain.hooks.on_syntax(args, context) "{{{
    syntax match uniteSource__SwiftToolchain_Normal /\~.*/
                \ contained containedin=uniteSource__SwiftToolchain
    syntax match uniteSource__SwiftToolchain_Normal_Marker /\~/
                \ contained containedin=uniteSource__SwiftToolchain_Normal
                \ conceal
    syntax match uniteSource__SwiftToolchain_Link /\/.*/
                \ contained containedin=uniteSource__SwiftToolchain
    syntax match uniteSource__SwiftToolchain_Link_Marker /\//
                \ contained containedin=uniteSource__SwiftToolchain_Link
                \ conceal
    syntax match uniteSource__SwiftToolchain_DisplayName /\~.*/
                \ contained containedin=uniteSource__SwiftToolchain_Link
    syntax match uniteSource__SwiftToolchain_DisplayName_Marker /\~/
                \ contained containedin=uniteSource__SwiftToolchain_DisplayName
                \ conceal
    highlight default link uniteSource__SwiftToolchain_DisplayName Comment
endfunction "}}}

" Actions {{{

let s:source_toolchain.action_table.set_buffer = {
            \ 'description': 'select the Swift toolchain (buffer-local)',
            \ 'is_selectable': 0
            \}
function! s:source_toolchain.action_table.set_buffer.func(candidate) "{{{
    if empty(a:candidate.word)
        unlet! b:swift_toolchain
    else
        let b:swift_toolchain = a:candidate.word
    endif
endfunction "}}}

let s:source_toolchain.action_table.set_global = {
            \ 'description': 'select the Swift toolchain (global)',
            \ 'is_selectable': 0
            \}
function! s:source_toolchain.action_table.set_global.func(candidate) "{{{
    if empty(a:candidate.word)
        unlet! g:swift_toolchain
    else
        let g:swift_toolchain = a:candidate.word
    endif
endfunction "}}}

" }}}

" }}}

let &cpo = s:save_cpo
unlet s:save_cpo
