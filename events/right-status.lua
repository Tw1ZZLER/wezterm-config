local wezterm = require('wezterm')
local umath = require('utils.math')
local Cells = require('utils.cells')
local GpuAdapters = require('utils.gpu-adapter')
local OptsValidator = require('utils.opts-validator')

---@alias Event.RightStatusOptions { date_format?: string }

---Setup options for the right status bar
local EVENT_OPTS = {}

---@type OptsSchema
EVENT_OPTS.schema = {
   {
      name = 'date_format',
      type = 'string',
      default = '%a %H:%M:%S',
   },
}
EVENT_OPTS.validator = OptsValidator:new(EVENT_OPTS.schema)

local nf = wezterm.nerdfonts
local attr = Cells.attr

local M = {}

local ICON_SEPARATOR = nf.oct_dash
local ICON_DATE = nf.fa_calendar
local ICON_DISCRETE_GPU = nf.md_expansion_card_variant
local ICON_INTEGRATED_GPU = nf.md_chip

---@type string[]
local discharging_icons = {
   nf.md_battery_10,
   nf.md_battery_20,
   nf.md_battery_30,
   nf.md_battery_40,
   nf.md_battery_50,
   nf.md_battery_60,
   nf.md_battery_70,
   nf.md_battery_80,
   nf.md_battery_90,
   nf.md_battery,
}
---@type string[]
local charging_icons = {
   nf.md_battery_charging_10,
   nf.md_battery_charging_20,
   nf.md_battery_charging_30,
   nf.md_battery_charging_40,
   nf.md_battery_charging_50,
   nf.md_battery_charging_60,
   nf.md_battery_charging_70,
   nf.md_battery_charging_80,
   nf.md_battery_charging_90,
   nf.md_battery_charging,
}

---@type table<string, Cells.SegmentColors>
-- stylua: ignore
local colors = {
   separator = { fg = '#9399b2', bg = 'rgba(0, 0, 0, 0.4)' },
   date      = { fg = '#f38ba8', bg = 'rgba(0, 0, 0, 0.4)' },
   battery   = { fg = '#a6e3a1', bg = 'rgba(0, 0, 0, 0.4)' },
   gpu_intel = { fg = '#89b4fa', bg = 'rgba(0, 0, 0, 0.4)' },
   gpu_amd   = { fg = '#f38ba8', bg = 'rgba(0, 0, 0, 0.4)' },
   gpu_nvidia = { fg = '#94e2d5', bg = 'rgba(0, 0, 0, 0.4)' },
}

local cells = Cells:new()

cells
   :add_segment('date_icon', ICON_DATE .. '  ', colors.date, attr(attr.intensity('Bold')))
   :add_segment('date_text', '', colors.date, attr(attr.intensity('Bold')))
   :add_segment('separator', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('battery_icon', '', colors.battery)
   :add_segment('battery_text', '', colors.battery, attr(attr.intensity('Bold')))
   :add_segment('gpu_icon', '  ', colors.gpu, attr(attr.intensity('Bold')))
   :add_segment('gpu_adapter', '', colors.gpu, attr(attr.intensity('Bold')))
---@return string, string
local function battery_info()
   -- ref: https://wezfurlong.org/wezterm/config/lua/wezterm/battery_info.html

   local charge = ''
   local icon = ''

   for _, b in ipairs(wezterm.battery_info()) do
      local idx = umath.clamp(umath.round(b.state_of_charge * 10), 1, 10)
      charge = string.format('%.0f%%', b.state_of_charge * 100)

      if b.state == 'Charging' then
         icon = charging_icons[idx]
      else
         icon = discharging_icons[idx]
      end
   end

   return charge, icon .. ' '
end

---@return string, string
local function gpu_info()
   -- ref: https://wezfurlong.org/wezterm/config/lua/wezterm/gpu_adapters.html
   local gpu = GpuAdapters:pick_best()
   if not gpu then
      return '', ''
   end
   local gpu_name = gpu.name or ''
   local gpu_backend = gpu.backend or ''

   -- Check if the GPU is Intel, AMD, or NVIDIA and set the color accordingly
   if string.match(gpu_name, 'Intel') then
      cells:update_segment_colors('gpu_adapter', colors.gpu_intel)
   elseif string.match(gpu_name, 'AMD') then
      cells:update_segment_colors('gpu_adapter', colors.gpu_amd)
   elseif string.match(gpu_name, 'NVIDIA') then
      cells:update_segment_colors('gpu_adapter', colors.gpu_nvidia)
   end

   -- Check if integrated or discrete and change icon
   if gpu.device_type == 'IntegratedGpu' then
      cells:update_segment_text('gpu_icon', ICON_INTEGRATED_GPU .. ' ')
   else
      cells:update_segment_text('gpu_icon', ICON_DISCRETE_GPU .. ' ')
   end

   return gpu_name, gpu_backend
end

---@param opts? Event.RightStatusOptions Default: {date_format = '%a %H:%M:%S'}
M.setup = function(opts)
   local valid_opts, err = EVENT_OPTS.validator:validate(opts or {})

   if err then
      wezterm.log_error(err)
   end

   wezterm.on('update-right-status', function(window, _pane)
      local battery_text, battery_icon = battery_info()
      local gpu_name, gpu_backend = gpu_info()

      cells
         :update_segment_text('date_text', wezterm.strftime(valid_opts.date_format))
         :update_segment_text('battery_icon', battery_icon)
         :update_segment_text('battery_text', battery_text)
         :update_segment_text('gpu_adapter', gpu_name .. ' (' .. gpu_backend .. ')')

      window:set_right_status(wezterm.format(cells:render({
         -- 'date_icon',
         -- 'date_text',
         -- 'separator',
         -- 'battery_icon',
         -- 'battery_text',
         -- 'separator',
         'gpu_icon',
         'gpu_adapter',
      })))
   end)
end

return M
