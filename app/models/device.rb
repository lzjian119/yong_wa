#coding: utf-8
# == Schema Information
#
# Table name: devices
#
#  id            :integer          not null, primary key
#  series_code   :string(255)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  sex           :string(255)
#  birth         :string(255)
#  height        :string(255)
#  weight        :string(255)
#  mobile        :string(255)
#  imei          :string(255)
#  device_name   :string(255)
#  active        :boolean
#  config_info   :text(65535)
#  tracking_info :text(16777215)
#  health_info   :text(65535)
#

class Device < ActiveRecord::Base
  has_many :user_device
  has_many :history

  before_create :set_device_name

  DEFAULT_CONFIG = {
    sos: [
          "0",
          "0",
          "0"
      ],

    babyPhoneNumber: [
      {
        name: "勇娃售后服务",
        value: "4006791679"
        }
      ],

    monitor: "1",
    workMode: "0",

    freeTime: [
        "00:00-00:00",
        "00:00-00:00",
        "00:00-00:00",
        "00:00-00:00"
      ],

    schoolPositioning: [
        "00:00-00:00",
        "00:00-00:00",
        "00:00-00:00",
        "00:00-00:00"
      ],

    weekendPositioning: [
        "00:00-00:00",
        "00:00-00:00",
        "00:00-00:00",
        "00:00-00:00"
      ],

    lowPowerWarning: "0",
    sosWarning: "0",
    findWatch: "1",
    closeWatch: "1",
    remindInfo: [
      "08:10-1-1",
      "08:10-1-2",
      "08:10-1-3-0111110"
    ],
    electronicFence: {
      center: "22.564025,N,113.242329,E",
      radius: 1000
    },
    electronicFenceOn: "0",
    location: "1",
    shoot: "18565739316",
    watch_keypad: "1"
  }

  DEFAULT_TRACKING_RECORD = [
    {
      time: "10:19:30",
      gps_sig: "A",
      geo_loc: "22.564025,N,113.242329,E"
    }
  ]

  DEFAULT_HEALTH_RECORD = {
    step_zero_count: 0,
    step_extra: 0,
    turn_zero_count: 0,
    turn_extra: 0,
    move_distance_zero_count: 0,
    move_distance_extra: 0,
    move_calorie_zero_count: 0,
    move_calorie_extra: 0
  }


  def self.exist?(device)
    device = Device.find_by(series_code: device)
    if device != nil
      true
    else
      false
    end
  end

  def reset
    user_device = UserDevice.find_by(device: self)
    user_device.delete if user_device
    #Todo active false or true
    self.update!(mobile: nil, active: true, config_info: nil, tracking_info: nil, health_info: nil)
  end

  def get_config
    if !self.config_info
      self.config_info = DEFAULT_CONFIG.to_json
      self.save!
    end
    JSON.parse(self.config_info, symbolize_names: true)
  end

  def set_config_field(key, value)
    self.config_info ||= DEFAULT_CONFIG.to_json
    hash_values = JSON.parse(config_info, symbolize_names: true)
    hash_values[key.to_sym] = value
    update!(config_info: hash_values.to_json)
  end

  def get_config_field(key)
    info = self.config_info || DEFAULT_CONFIG.to_json
    hash_values = JSON.parse(info, symbolize_names: true)
    hash_values[key.to_sym] || DEFAULT_CONFIG[key.to_sym]
  end

  def get_tracking_record(begin_date, end_date)
    begin
      hash_data = JSON.parse(self.tracking_info, symbolize_names: true)
    rescue Exception => e
      puts e.message
      hash_data = {}
    end

    hash_selection = {}
    current_date = begin_date
    while DateString.compare_less_or_equal(current_date, end_date)
      prev_date = DateString.prev_day(current_date)
      default_date = hash_data[prev_date.to_sym] != nil ? [hash_data[prev_date.to_sym].last] : nil
      default_date ||= hash_selection[prev_date.to_sym] != nil ? [hash_selection[prev_date.to_sym].last] : nil
      default_date ||= [DEFAULT_TRACKING_RECORD]
      hash_selection[current_date.to_sym] = hash_data[current_date.to_sym] || default_date
      current_date = DateString.next_day(current_date)
    end
    hash_selection
  end

  def get_health_info(begin_date, end_date)
    begin
      hash_data = JSON.parse(self.health_info, symbolize_names: true)
    rescue Exception => e
      puts e.message
      puts e.backtrace.join("\n")
      hash_data = {}
    end

    begin

    result = {step: 0, turn: 0, move_distance: 0, move_calorie: 0}
    current_date = DateString.prev_day(begin_date)
    while DateString.compare_less_or_equal(current_date, end_date)
      ["step", "turn", "move_distance", "move_calorie"].each do |key|
        hash_selection = hash_data[current_date.to_sym] || DEFAULT_HEALTH_RECORD
        key_zero_count = (key + "_zero_count").to_sym
        key_extra = (key + "_extra").to_sym
        #prev begin day
        if current_date == DateString.prev_day(begin_date)
          #binding.pry
          result[key.to_sym] += - (hash_selection[key_extra] || 0 )
        elsif current_date == end_date
          #if key == "turn"
           # binding.pry
          #end
          
          result[key.to_sym] += (hash_selection[key_extra] || 0) + (hash_selection[key_zero_count] || 0)
        else
          result[key.to_sym] += hash_selection[key_zero_count] || 0
        end
      end
      current_date = DateString.next_day(current_date)
    end
    
    rescue Exception => e
      puts e.backtrace.join("\n")
    end

    result
  end

  def add_health_info_zero_count(current_date, params = {})
    begin
      hash_data = JSON.parse(self.health_info, symbolize_names: true)
    rescue Exception => e
      puts e.message
      hash_data = {}
    end

    if hash_data[current_date.to_sym] == nil
      hash_data[current_date.to_sym] = {}
    end
    data_json = hash_data[current_date.to_sym]
    ["step", "turn", "move_distance", "move_calorie"].each do |key|
      key_zero_count = (key + "_zero_count").to_sym
      key_extra = (key + "_extra").to_sym
      data_json[key_zero_count] ||= 0
      data_json[key_zero_count] += (params[key_zero_count] || 0)
      data_json[key_extra] = 0
    end
    hash_data[current_date.to_sym] = data_json
    update(health_info: hash_data.to_json)
  end

  def set_health_info_extra(current_date, params = {})
    begin
      hash_data = JSON.parse(self.health_info, symbolize_names: true)
    rescue Exception => e
      puts e.message
      hash_data = {}
    end

    if hash_data[current_date.to_sym] == nil
      hash_data[current_date.to_sym] = {}
    end
    hash_data[current_date.to_sym].merge!(params)
    update(health_info: hash_data.to_json)
  end


  #response_report_geo
  #response_report_geo_2
  def add_tracking_record_geo(data_str)
    begin
      hash_data = JSON.parse(self.tracking_info, symbolize_names: true)
    rescue Exception => e
      puts e.message
      hash_data = {}
    end

    data_array = data_str.split(",")
    date_str = data_array[0]
    time_str = data_array[1]
    date_format = "20#{date_str[4..5]}-#{date_str[2..3]}-#{date_str[0..1]}"

    new_record = {}
    new_record[:time] = "#{time_str[0..1]}:#{time_str[2..3]}:#{time_str[4..5]}"
    new_record[:gps_sig] = data_array[2]

    if new_record[:gps_sig] == "V"
      if !data_array[19] || !data_array[20] || !data_array[21]
        return
      end
      v_pos = ApplicationController.helpers.get_v_position(data_array[19],data_array[20], data_array[21])
      new_record[:geo_loc] = [v_pos[:lat], "N", v_pos[:long], "E"].join(",") if v_pos[:lat] && v_pos[:long]
    elsif new_record[:gps_sig] == "A"
      new_record[:geo_loc] = data_array[3..6].join(",")
    end

    ef_info = get_config_field(:electronicFence)

    if ef_info == DEFAULT_CONFIG[:electronicFence] && new_record[:geo_loc]
      set_config_field(:electronicFence, 
                        {
                          center: new_record[:geo_loc],
                          radius: 1000
                          })
    end
    #new_record[:velocity] = data_array[7]
    #new_record[:direction] = data_array[8]
    #new_record[:other] = data_array[9..-1].to_s
    
    # if new_record[:gps_sig] == "V"
    #   return
    # end

    if get_config_field(:electronicFenceOn).to_s == "1" && is_out_fence(new_record[:geo_loc])[0]
      #ApplicationController.helpers.send_fence_warning_for_device(self)
      params = {}
      params[:watch_electronicFence] = "1"
      params[:watch_data] = new_record[:geo_loc]
      History.create(device: self, data_content: params.to_s)
    end

    if hash_data[date_format.to_sym] == nil
      hash_data[date_format.to_sym] = []
    end
    hash_data[date_format.to_sym].append(new_record)
    
    date_week_ago = DateString.week_ago(date_format)
    if hash_data[date_week_ago.to_sym] != nil
      date_week_ago = DateString.next_day(date_week_ago)
      hash_data = hash_data.select {
        |k, v| DateString.compare_less_or_equal(date_week_ago, k.to_s)
      }      
    end

    update(tracking_info: hash_data.to_json)
  end

  def self.find_device(device_str)
    Device.find_by(series_code: device_str)
  end

  def self.clear_all_configs
    devices = Device.all
    devices.each do |d|
      d.update(config_info: nil)
    end
  end

  def self.clear_all_health_info
    devices = Device.all
    devices.each do |d|
      d.update(health_info: nil)
    end
  end

  def self.clear_all_tracking
    devices = Device.all
    devices.each do |d|
      d.update(tracking_info: nil)
    end
  end

  def is_out_fence(current_geo)
    puts "current_geo --------- #{current_geo}"
    config_info = get_config_field(:electronicFence)
    return [false, {dist: -1, radius: -1}] if config_info == nil

    radius = config_info[:radius].to_f
    center = config_info[:center]
    center_lat = center.split(",")[0].to_f
    center_long = center.split(",")[2].to_f

    current_lat = current_geo[0].to_f
    current_long = current_geo[2].to_f
    dist = GeoDistance::Haversine.distance( center_lat, center_long, current_lat, current_long )

    return [dist >= radius, {dist: dist, radius: radius}]
  end

  private
    def set_device_name
      self.device_name ||= self.series_code
      self.sex  ||= "男"
      self.birth ||= "20150101"
      self.height ||= "100cm"
      self.weight ||= "30kg"
    end

end
