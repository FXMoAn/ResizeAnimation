local obs = obslua

-- 插件介绍
function script_description()
    return [[
        <center><h1><color=#0000FF>自定义缩放动画效果</color></h1></center>
        <center><h2>作者：墨安</h2></center>
        <center>Inspired by Jojoe's resize animation script</center>
    ]]
end

-- 插件设置
function script_properties()
    local settings = obs.obs_properties_create()

    local scene_list = obs.obs_properties_add_list(settings, "scene_list", "选择场景: ", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    make_scene_list(scene_list)
    local source_list = obs.obs_properties_add_list(settings, "source_list", "选择源（窗口）: ", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    make_source_list(source_list)
    local animation_type_list = obs.obs_properties_add_list(settings, "animation_type_list", "选择动画类型: ", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    make_animation_type_list(animation_type_list)
    
    -- 添加动画时长设置
    obs.obs_properties_add_int_slider(settings, "animation_duration", "动画时长 (毫秒): ", 100, 5000, 100)
    obs.obs_properties_add_bool(settings, "enable_bounce", "启用弹跳效果")
    obs.obs_properties_add_int_slider(settings, "bounce_duration", "弹跳时长 (毫秒): ", 100, 2000, 100)

    return settings
end

-- 获取场景列表
function make_scene_list(scene_list)
    local scenes = obs.obs_frontend_get_scenes()
    if scenes ~= nil then
        for i, scene in ipairs(scenes) do
            local name = obs.obs_source_get_name(scene)
            obs.obs_property_list_add_string(scene_list, name, name)
        end
        obs.source_list_release(scenes)
    end
end

-- 获取源列表
function make_source_list(source_list)
    local sources = obs.obs_enum_sources()
    if sources ~= nil then
        for i, source in ipairs(sources) do
            local name = obs.obs_source_get_name(source)
            obs.obs_property_list_add_string(source_list, name, name)
        end
        obs.source_list_release(sources)
    end
end

-- 获取动画类型
function make_animation_type_list(animation_type_list)
    obs.obs_property_list_add_string(animation_type_list, "缓入", "ease_in")
    obs.obs_property_list_add_string(animation_type_list, "缓出", "ease_out")
    obs.obs_property_list_add_string(animation_type_list, "缓入缓出", "ease_in_out")
    obs.obs_property_list_add_string(animation_type_list, "线性", "linear")
end

-- 缓动函数
function ease_in(t)
    return t * t
end

function ease_out(t)
    return 1 - (1 - t) * (1 - t)
end

function ease_in_out(t)
    if t < 0.5 then
        return 2 * t * t
    else
        return 1 - 2 * (1 - t) * (1 - t)
    end
end

function linear(t)
    return t
end

-- 获取缓动函数
function get_easing_function(easing_type)
    if easing_type == "ease_in" then
        return ease_in
    elseif easing_type == "ease_out" then
        return ease_out
    elseif easing_type == "ease_in_out" then
        return ease_in_out
    else
        return linear
    end
end

-- 拉伸到边界
function ensure_stretch_to_bounds()
    local scene = obs.obs_get_scene_by_name(scene_name)
    if not scene then
        return
    end
    
    local sceneitem = obs.obs_scene_find_source(scene, source_name)
    if not sceneitem then
        obs.obs_scene_release(scene)
        return
    end
    
    obs.obs_sceneitem_set_bounds_type(sceneitem, 1) -- 拉伸到边界
    obs.obs_sceneitem_set_bounds_alignment(sceneitem, 5) -- 左上对齐
    obs.obs_sceneitem_set_alignment(sceneitem, 5) -- 左上对齐

    obs.obs_scene_release(scene)
end

-- 更新设置
function script_update(settings)
    -- 动画相关变量
    animation_start_time = 0
    animation_duration = obs.obs_data_get_int(settings, "animation_duration")
    animation_type = obs.obs_data_get_string(settings, "animation_type_list")
    enable_bounce = obs.obs_data_get_bool(settings, "enable_bounce")
    bounce_duration = obs.obs_data_get_int(settings, "bounce_duration")
    
    -- 动画状态
    is_animating = false
    is_bouncing = false
    
    -- 起始和目标尺寸
    start_width = 0
    start_height = 0
    target_width = 0
    target_height = 0
    
    local video_info = obs.obs_video_info()
    obs.obs_get_video_info(video_info)    
    canvas_width = video_info.base_width
    canvas_height = video_info.base_height
    
    source_name = obs.obs_data_get_string(settings, "source_list")
    scene_name = obs.obs_data_get_string(settings, "scene_list")

    ensure_stretch_to_bounds()

    local source = obs.obs_get_source_by_name(source_name)
    if source then
        prev_width = obs.obs_source_get_width(source)
        prev_height = obs.obs_source_get_height(source)
        obs.obs_source_release(source)
    end

    obs.timer_remove(update_size)
    obs.timer_add(update_size, 100)
end

-- 获取实例宽高和位置
function get_instance_position()
    local scene = obs.obs_get_scene_by_name(scene_name)
    if not scene then
        return 0, 0, 0, 0
    end
    
    local sceneitem = obs.obs_scene_find_source(scene, source_name)
    if not sceneitem then
        obs.obs_scene_release(scene)
        return 0, 0, 0, 0
    end
    
    local info = obs.obs_transform_info()
    obs.obs_sceneitem_get_info(sceneitem, info)

    local w = info.bounds.x
    local h = info.bounds.y
    local x = info.pos.x
    local y = info.pos.y
    obs.obs_scene_release(scene)

    return w, h, x, y
end

-- 调整实例宽高和位置
function resize_instance(w, h, x, y)
    local scene = obs.obs_get_scene_by_name(scene_name)
    if not scene then
        return
    end
    
    local sceneitem = obs.obs_scene_find_source(scene, source_name)
    if not sceneitem then
        obs.obs_scene_release(scene)
        return
    end
    
    local info = obs.obs_transform_info()
    obs.obs_sceneitem_get_info(sceneitem, info)

    info.bounds.x = w
    info.bounds.y = h
    info.pos.x = x
    info.pos.y = y

    obs.obs_sceneitem_set_info(sceneitem, info)

    obs.obs_scene_release(scene)
end

function update_size()
    local source = obs.obs_get_source_by_name(source_name)
    if not source then
        return
    end
    
    width = obs.obs_source_get_width(source)
    height = obs.obs_source_get_height(source)
    obs.obs_source_release(source)

    if width ~= prev_width or height ~= prev_height then
        prev_width = width
        prev_height = height
        print("检测到尺寸变化: " .. width .. "x" .. height)
        
        if width > 0 and height > 0 and not is_animating then
            start_animation(width, height)
        end
    end
end

function start_animation(new_width, new_height)
    if is_animating then
        return
    end
    
    -- 获取当前实例尺寸
    start_width, start_height = get_instance_position()
    target_width = new_width
    target_height = new_height
    
    -- 开始动画
    is_animating = true
    animation_start_time = obs.os_gettime_ns() / 1000000 -- 转换为毫秒
    
    print("开始动画: " .. start_width .. "x" .. start_height .. " -> " .. target_width .. "x" .. target_height)
    print("动画时长: " .. animation_duration .. "ms")
    
    obs.timer_remove(update_size)
    obs.timer_add(animate, 16)
end

function animate()
    local current_time = obs.os_gettime_ns() / 1000000
    local elapsed_time = current_time - animation_start_time
    local progress = math.min(elapsed_time / animation_duration, 1.0)

    local easing_func = get_easing_function(animation_type)
    local eased_progress = easing_func(progress)
    
    -- 计算当前尺寸
    local current_width = start_width + (target_width - start_width) * eased_progress
    local current_height = start_height + (target_height - start_height) * eased_progress
    
    -- 计算位置
    local pos_x = (canvas_width / 2) - (current_width / 2)
    local pos_y = (canvas_height / 2) - (current_height / 2)
    
    -- 应用尺寸和位置
    resize_instance(current_width, current_height, pos_x, pos_y)
    
    if progress >= 1.0 then
        print("动画完成")
        obs.timer_remove(animate)

        if enable_bounce and not is_bouncing then
            start_bounce_animation()
        else
            is_animating = false
            obs.timer_add(update_size, 100)
        end
    end
end

function start_bounce_animation()
    if is_bouncing then
        return
    end
    
    is_bouncing = true
    bounce_start_time = obs.os_gettime_ns() / 1000000
    bounce_start_width = target_width
    bounce_start_height = target_height
    
    print("开始弹跳动画")
    
    obs.timer_add(bounce_animate, 16)
end

function bounce_animate()
    local current_time = obs.os_gettime_ns() / 1000000
    local elapsed_time = current_time - bounce_start_time
    local progress = math.min(elapsed_time / bounce_duration, 1.0)

    local bounce_factor = math.sin(progress * math.pi) * math.exp(-progress * 3)
    local bounce_offset = 20 * bounce_factor
    if progress >= 1.0 then
        bounce_offset = 0
    end

    local current_width = target_width + bounce_offset
    local current_height = target_height + bounce_offset
    local pos_x = (canvas_width / 2) - (current_width / 2)
    local pos_y = (canvas_height / 2) - (current_height / 2)
    resize_instance(current_width, current_height, pos_x, pos_y)

    if progress >= 1.0 then
        print("弹跳动画完成")
        obs.timer_remove(bounce_animate)
        local final_pos_x = (canvas_width / 2) - (target_width / 2)
        local final_pos_y = (canvas_height / 2) - (target_height / 2)
        resize_instance(target_width, target_height, final_pos_x, final_pos_y)

        is_animating = false
        is_bouncing = false
        obs.timer_add(update_size, 100)
    end
end