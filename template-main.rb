#!/usr/bin/env ruby
# coding: utf-8
##############################################################################
# Copyright (c) 2014 Camera Bits, Inc.  All rights reserved.
#
# Developed by Hayo Baan
#
##############################################################################

TEMPLATE_DISPLAY_NAME = "500px"

##############################################################################

class U500pxConnectionSettingsUI

  include PM::Dlg
  include AutoAccessor
  include CreateControlHelper

  def initialize(pm_api_bridge)
    @bridge = pm_api_bridge
  end

  def create_controls(parent_dlg)
    dlg = parent_dlg
    create_control(:setting_name_static,      Static,       dlg, :label=>"Your Accounts:")
    create_control(:setting_name_combo,       ComboBox,     dlg, :editable=>false, :sorted=>true, :persist=>false)
    create_control(:setting_delete_button,    Button,       dlg, :label=>"Delete Account")
    create_control(:setting_add_button,       Button,       dlg, :label=>"Add/Replace Account")
    create_control(:add_account_instructions, Static,       dlg, :label=>"Note on ading an account: If you have an active 500px session in your browser, 500px will authorize Photo Mechanic for the username associated with that session. Otherwise, 500px will prompt you to login.\nAfter authorizing Photo Mechanic, please enter the verification code into the dialog. The account name will be determined automatically from your 500px user name.")
  end

  def layout_controls(container)
    sh, eh = 20, 24
    c = container
    c.set_prev_right_pad(5).inset(10,10,0,-10).mark_base
    c << @setting_name_static.layout(0, c.base, -1, sh)
    c.pad_down(0).mark_base
    c << @setting_name_combo.layout(0, c.base, -1, eh)
    c.pad_down(5).mark_base
    c << @setting_delete_button.layout(0, c.base, "50%-5", eh)
    c << @setting_add_button.layout("-50%+5", c.base, -1, eh)
    c.pad_down(5).mark_base
    c << add_account_instructions.layout(0, c.base, -1, 4*sh)
  end
end

class U500pxConnectionSettings
  include PM::ConnectionSettingsTemplate

  DLG_SETTINGS_KEY = :connection_settings_dialog

  def self.template_display_name  # template name shown in dialog list box
    TEMPLATE_DISPLAY_NAME
  end

  def self.template_description  # shown in dialog box
    "500px Connection Settings"
  end

  def self.fetch_settings_data(serializer)
    dat = serializer.fetch(DLG_SETTINGS_KEY, :settings) || {}
    SettingsData.deserialize_settings_hash(dat)
  end

  def self.store_settings_data(serializer, settings)
    settings_dat = SettingsData.serialize_settings_hash(settings)
    serializer.store(DLG_SETTINGS_KEY, :settings, settings_dat)
  end

  def self.fetch_selected_settings_name(serializer)
    serializer.fetch(DLG_SETTINGS_KEY, :selected_item)  # might be nil
  end

  class SettingsData
    attr_accessor :auth_token, :auth_token_secret
    
    def initialize(name, token, token_secret)
      @account_name = name
      @auth_token = token
      @auth_token_secret = token_secret
      self
    end
    
    def appears_valid?
      return ! (@account_name.nil? || @account_name.empty? || @auth_token.nil? || @auth_token.empty? || @auth_token_secret.nil? || @auth_token_secret.empty?)
    rescue
      false
    end

    def self.serialize_settings_hash(settings)
      out = {}
      settings.each_pair do |key, dat|
        out[key] = [dat.auth_token, dat.auth_token_secret]
      end
      out
    end

    def self.deserialize_settings_hash(input)
      settings = {}
      input.each_pair do |key, dat|
        token, token_secret = dat
        settings[key] = SettingsData.new(key, token, token_secret)
      end
      settings
    end

  end

  def initialize(pm_api_bridge)
    @bridge = pm_api_bridge
    @prev_selected_settings_name = nil
    @settings = {}
  end

  def settings_selected_item
    serializer.fetch(DLG_SETTINGS_KEY, :selected_item)
  end

  def create_controls(parent_dlg)
    @ui = U500pxConnectionSettingsUI.new(@bridge)
    @ui.create_controls(parent_dlg)
    add_event_handlers
  end

  def add_event_handlers
    @ui.setting_name_combo.on_sel_change { handle_sel_change }
    @ui.setting_delete_button.on_click { handle_delete_button }
    @ui.setting_add_button.on_click { handle_add_account }
  end

  def layout_controls(container)
    @ui.layout_controls(container)
  end

  def destroy_controls
    @ui = nil
  end

  def save_state(serializer)
    return unless @ui
    self.class.store_settings_data(serializer, @settings)
    serializer.store(DLG_SETTINGS_KEY, :selected_item, current_account_name)
  end

  def restore_state(serializer)
    @settings = self.class.fetch_settings_data(serializer)
    load_combo_from_settings
    select_previously_selected_account(serializer)
    select_first_account_if_none_selected
    store_selected_account
    load_current_values_from_settings
  end

  def select_previously_selected_account(serializer)
    @prev_selected_settings_name = serializer.fetch(DLG_SETTINGS_KEY, :selected_item)
    if @prev_selected_settings_name
      @ui.setting_name_combo.set_selected_item(@prev_selected_settings_name)
    end
  end

  def select_first_account_if_none_selected
    if @ui.setting_name_combo.get_selected_item.empty?  &&  @ui.setting_name_combo.num_items > 0
      @ui.setting_name_combo.set_selected_item( @ui.setting_name_combo.get_item_at(0) )
    end
  end

  def store_selected_account
    @prev_selected_settings_name = @ui.setting_name_combo.get_selected_item
    @prev_selected_settings_name = nil if @prev_selected_settings_name.empty?
  end

  def periodic_timer_callback
  end

  protected

  def load_combo_from_settings
    @ui.setting_name_combo.reset_content( @settings.keys )
  end

  def save_current_values_to_settings(params={:name=>nil, :replace=>true})
    key = params[:name] || current_account_name

    if key && key === String
      @settings[key] ||= SettingsData.new(key, nil, nil)
      key
    end
  end

  def current_account_name
    @ui.setting_name_combo.get_selected_item_text.to_s
  end

  def load_current_values_from_settings
    data = @settings[current_account_name]
  end

  def delete_in_settings(name)
    @settings.delete name
    @deleted = true
  end

  def add_account_to_dropdown(name = nil)
    save_current_values_to_settings(:name => name.to_s, :replace=>true)
    @ui.setting_name_combo.add_item(name.to_s)
    @ui.setting_name_combo.set_selected_item(name.to_s)
  end

  def handle_sel_change
    # NOTE: We rely fully on the prev. selected name here, because the
    # current selected name has already changed.
    if @prev_selected_settings_name
      save_current_values_to_settings(:name=>@prev_selected_settings_name, :replace=>true)
    end
    load_current_values_from_settings
    @prev_selected_settings_name = current_account_name
  end

  def clear_settings
    @ui.setting_name_combo.set_text ""
  end

  def client
    @client ||= U500pxClient.new(@bridge)
  end

  def handle_add_account
    save_account_callback = lambda do |client|
      if client.authenticated?
        @settings[client.name]  = SettingsData.new(client.name, client.access_token,client.access_token_secret)
        add_account_to_dropdown(client.name)
      end
    end
    client.get_500px_authorization(save_account_callback)
    @prev_selected_settings_name = nil
  end

  def handle_delete_button
    cur_name = current_account_name
    @ui.setting_name_combo.remove_item(cur_name) if @ui.setting_name_combo.has_item? cur_name
    delete_in_settings(cur_name)
    @prev_selected_settings_name = nil
    if @ui.setting_name_combo.num_items > 0
      @ui.setting_name_combo.set_selected_item( @ui.setting_name_combo.get_item_at(0) )
      handle_sel_change
    else
      clear_settings
    end
  end
end


################################################################################


class U500pxFileUploaderUI

  include PM::Dlg
  include AutoAccessor
  include CreateControlHelper
  include ImageProcessingControlsCreation
  include ImageProcessingControlsLayout
  include OperationsControlsCreation
  include OperationsControlsLayout

  SOURCE_RAW_LABEL = "Use the RAW"
  SOURCE_JPEG_LABEL = "Use the JPEG"

  def initialize(pm_api_bridge)
    @bridge = pm_api_bridge
  end

  # Is this function necessary???
#  def operations_enabled?
#    false
#  end

  def create_controls(parent_dlg)
    dlg = parent_dlg

    create_control(:dest_account_group_box,    GroupBox,    dlg, :label=>"Destination 500px Account:")
    create_control(:dest_account_static,       Static,      dlg, :label=>"Account")
    create_control(:dest_account_combo,        ComboBox,    dlg, :sorted=>true, :persist=>false)

    create_control(:meta_left_group_box,       GroupBox,    dlg, :label=>"500px Metadata:")
    create_control(:meta_category_static,      Static,      dlg, :label=>"Category")
    create_control(:meta_category_combo,       ComboBox,    dlg, :items=>[
                     "00 - Uncategorized",
                     "10 - Abstract",
                     "11 - Animals",
                     "05 - Black and White",
                     "01 - Celebrities",
                     "09 - City and Architecture",
                     "15 - Commercial",
                     "16 - Concert",
                     "20 - Family",
                     "14 - Fashion",
                     "02 - Film",
                     "24 - Fine Art",
                     "23 - Food",
                     "03 - Journalism",
                     "08 - Landscapes",
                     "12 - Macro",
                     "18 - Nature",
                     "04 - Nude",
                     "07 - People",
                     "19 - Performing Arts",
                     "17 - Sport",
                     "06 - Still Life",
                     "21 - Street",
                     "26 - Transportation",
                     "13 - Travel",
                     "22 - Underwater",
                     "27 - Urban Exploration",
                     "25 - Wedding"
                   ], :selected=>"00 - Uncategorized", :sorted=>false, :persist=>true)
    create_control(:meta_nsfw_check,           CheckBox,    dlg, :label=>"NotSafeForWork")
    create_control(:meta_license_type_static,  Static,      dlg, :label=>"License")
    create_control(:meta_license_type_combo,   ComboBox,    dlg, :items=>[
                     "00 - 500px License",
                     "04 - Attribution 3.0",
                     "05 - Attribution-NoDerivs 3.0",
                     "06 - Attribution-ShareAlike 3.0",
                     "01 - Attribution-NonCommercial 3.0",
                     "02 - Attribution-NonCommercial-NoDerivs 3.0",
                     "03 - Attribution-NonCommercial-ShareAlike 3.0"
                     # Names in api documentation:
                     # "00 - Standard 500px License",
                     # "04 - Creative Commons License Attribution",
                     # "05 - Creative Commons License No Derivatives",
                     # "06 - Creative Commons License Share Alike",
                     # "01 - Creative Commons License Non Commercial Attribution",
                     # "02 - Creative Commons License Non Commercial No Derivatives",
                     # "03 - Creative Commons License Non Commercial Share Alike"
                   ], :selected=>"00 - Standard 500px License", :sorted=>false, :persist=>true)
    create_control(:meta_privacy_check,        CheckBox,    dlg, :label=>"Privacy")
    create_control(:meta_name_static,          Static,      dlg, :label=>"Name")
    create_control(:meta_name_edit,            EditControl, dlg, :value=>"{headline}", :multiline=>true)
    create_control(:meta_description_static,   Static,      dlg, :label=>"Description")
    create_control(:meta_description_edit,     EditControl, dlg, :value=>"{caption}", :multiline=>true)
    create_control(:meta_tags_static,          Static,      dlg, :label=>"Tags")
    create_control(:meta_tags_edit,            EditControl, dlg, :value=>"{keywords}", :multiline=>true)

    create_control(:meta_right_group_box,      GroupBox,    dlg, :label=>"500px Metadata:")
    create_control(:meta_camera_static,        Static,      dlg, :label=>"Camera")
    create_control(:meta_camera_edit,          EditControl, dlg, :value=>"{model}", :multiline=>false)
    create_control(:meta_lens_static,          Static,      dlg, :label=>"Lens")
    create_control(:meta_lens_edit,            EditControl, dlg, :value=>"{lenstype}", :multiline=>false)
    create_control(:meta_focal_length_static,  Static,      dlg, :label=>"Focal length")
    create_control(:meta_focal_length_edit,    EditControl, dlg, :value=>"{lens}", :multiline=>false)
    create_control(:meta_aperture_static,      Static,      dlg, :label=>"Aperture")
    create_control(:meta_aperture_edit,        EditControl, dlg, :value=>"{aperture}", :multiline=>false)
    create_control(:meta_shutter_speed_static, Static,      dlg, :label=>"Shutter")
    create_control(:meta_shutter_speed_edit,   EditControl, dlg, :value=>"{shutter}", :multiline=>false)
    create_control(:meta_iso_static,           Static,      dlg, :label=>"ISO")
    create_control(:meta_iso_edit,             EditControl, dlg, :value=>"{iso}", :multiline=>false)
    # Currently, the 500px api doesn't allow setting "taken at" :-(
    # create_control(:meta_taken_at_static,      Static,      dlg, :label=>"Taken at")
    # create_control(:meta_taken_at_edit,        EditControl, dlg, :value=>"{day0}/{month0}/{year4} {time}", :multiline=>false)
    create_control(:meta_latitude_static,      Static,      dlg, :label=>"Latitude")
    create_control(:meta_latitude_edit,        EditControl, dlg, :value=>"{latitude}", :multiline=>false)
    create_control(:meta_longitude_static,     Static,      dlg, :label=>"Longitude")
    create_control(:meta_longitude_edit,       EditControl, dlg, :value=>"{longitude}", :multiline=>false)
  
    create_control(:transmit_group_box,        GroupBox,    dlg, :label=>"Transmit:")
    create_control(:send_original_radio,       RadioButton, dlg, :label=>"Original Photos")
    create_control(:send_jpeg_radio,           RadioButton, dlg, :label=>"Saved as JPEG", :checked=>true)
    RadioButton.set_exclusion_group(@send_original_radio, @send_jpeg_radio)
    create_control(:send_desc_edit,            EditControl, dlg, :value=>"Note: 500px's supported image formats are PNG, JPG and GIF.", :multiline=>true, :readonly=>true, :persist=>false)
    create_jpeg_controls(dlg)
    create_image_processing_controls(dlg)
    create_operations_controls(dlg)
  end

  def layout_controls(container)
    sh, eh = 20, 24

    container.inset(15, 5, -5, -5)

    container.layout_with_contents(@dest_account_group_box, 0, 0, -1, -1) do |c|
      c.set_prev_right_pad(5).inset(10,20,-10,-5).mark_base

      c << @dest_account_static.layout(0, c.base+3, 80, sh)
      c << @dest_account_combo.layout(c.prev_right, c.base, 200, eh)

      c.pad_down(5).mark_base
      c.mark_base.size_to_base
    end

    container.pad_down(5).mark_base

    container.layout_with_contents(@meta_left_group_box, 0, container.base, "50%-5", -1) do |c|
      c.set_prev_right_pad(5).inset(10,20,-10,-5).mark_base
      
      c << @meta_category_static.layout(0, c.base+3, 80, sh)
      c << @meta_category_combo.layout(c.prev_right, c.base, 185, eh)
      c << @meta_nsfw_check.layout(c.prev_right+10, c.base, -1, sh)
      c.pad_down(5).mark_base
     
      c << @meta_license_type_static.layout(0, c.base+3, 80, sh)
      c << @meta_license_type_combo.layout(c.prev_right, c.base, 185, eh)
      c << @meta_privacy_check.layout(c.prev_right+10, c.base, -1, sh)
      c.pad_down(5).mark_base

      # Not sure why this one is neceassary to line up left and right...
      c.pad_down(1).mark_base

      c << @meta_name_static.layout(0, c.base, 80, sh)
      c << @meta_name_edit.layout(c.prev_right, c.base, -1, eh*2)
      c.pad_down(9).mark_base
      
      c << @meta_description_static.layout(0, c.base, 80, sh)
      c << @meta_description_edit.layout(c.prev_right, c.base, -1, eh*2)
      c.pad_down(9).mark_base
      
      c << @meta_tags_static.layout(0, c.base, 80, sh)
      c << @meta_tags_edit.layout(c.prev_right, c.base, -1, eh*2)
      c.pad_down(9).mark_base

      c.mark_base.size_to_base
    end
    
    container.layout_with_contents(@meta_right_group_box, "-50%+5", container.base, -1, -1) do |c|
      c.set_prev_right_pad(5).inset(10,20,-10,-5).mark_base

      # Not sure why this one is neceassary to line up left and right...
      c.pad_down(1).mark_base

      c << @meta_camera_static.layout(0, c.base, 80, sh)
      c << @meta_camera_edit.layout(c.prev_right, c.base, -1, eh)
      c.pad_down(5).mark_base
      c << @meta_lens_static.layout(0, c.base, 80, sh)
      c << @meta_lens_edit.layout(c.prev_right, c.base, -1, eh)
      c.pad_down(5).mark_base
      c << @meta_focal_length_static.layout(0, c.base, 80, sh)
      c << @meta_focal_length_edit.layout(c.prev_right, c.base, -1, eh)
      c.pad_down(5).mark_base
      c << @meta_aperture_static.layout(0, c.base, 80, sh)
      c << @meta_aperture_edit.layout(c.prev_right, c.base, -1, eh)
      c.pad_down(5).mark_base
      c << @meta_shutter_speed_static.layout(0, c.base, 80, sh)
      c << @meta_shutter_speed_edit.layout(c.prev_right, c.base, -1, eh)
      c.pad_down(5).mark_base
      c << @meta_iso_static.layout(0, c.base, 80, sh)
      c << @meta_iso_edit.layout(c.prev_right, c.base, -1, eh)
      c.pad_down(5).mark_base
      # c << @meta_taken_at_static.layout(0, c.base, 80, sh)
      # c << @meta_taken_at_edit.layout(c.prev_right, c.base, -1, eh)
      # c.pad_down(5).mark_base
      c << @meta_latitude_static.layout(0, c.base, 80, sh)
      c << @meta_latitude_edit.layout(c.prev_right, c.base, -1, eh)
      c.pad_down(5).mark_base
      c << @meta_longitude_static.layout(0, c.base, 80, sh)
      c << @meta_longitude_edit.layout(c.prev_right, c.base, -1, eh)
      c.pad_down(5).mark_base

      c.mark_base.size_to_base
    end

    container.pad_down(5).mark_base
    container.mark_base.size_to_base

    container.pad_down(5).mark_base

    container.layout_with_contents(@operations_group_box, "50%+5", container.base, -1, -1) do |c|
      c.set_prev_right_pad(5).inset(10,20,-10,-5).mark_base

      c << @apply_iptc_check.layout(0, c.base, "50%-5", eh)
      c << @stationery_pad_btn.layout("-50%+5", c.base, -1, eh)
      c.pad_down(5).mark_base
      c << @preserve_exif_check.layout(0, c.base, -1, eh)
      c.pad_down(5).mark_base

      c << @save_copy_check.layout(0, c.base, -1, eh)
      c.pad_down(5).mark_base
      c << @save_copy_subdir_radio.layout(30, c.base, "50%-35", eh)
      c << @save_copy_subdir_edit.layout("50%+5", c.base, -1, eh)
      c.pad_down(5).mark_base
      c << @save_copy_userdir_radio.layout(30, c.base, "50%", eh)
      c << @save_copy_choose_userdir_btn.layout("50%+5", c.base, -1, eh)
      c.pad_down(5).mark_base
      c << @save_copy_userdir_static.layout(0, c.base, -1, 2*sh)

      c.pad_down(5).mark_base
      c.mark_base.size_to_base
    end

    container.layout_with_contents(@transmit_group_box, 0, container.base, "50%-5", -1) do |c|
      c.set_prev_right_pad(5).inset(10,20,-10,-5).mark_base

      c << @send_original_radio.layout(0, c.base, 120, eh)
      c << @send_jpeg_radio.layout(0, c.base+eh+5, 120, eh)
      c << @send_desc_edit.layout(c.prev_right+5, c.base, -1, 2*eh)
      c.pad_down(5).mark_base

      layout_jpeg_controls(c, eh, sh)

      c.layout_with_contents(@imgproc_group_box, 0, c.base, -1, -1) do |cc|
        cc.set_prev_right_pad(5).inset(10,20,-10,-5).mark_base
        
        layout_image_processing_controls(cc, eh, sh, 80, 200, 120)

        cc.pad_down(5).mark_base
        cc.mark_base.size_to_base
      end

      c.pad_down(5).mark_base
      c.mark_base.size_to_base
    end

    container.pad_down(5).mark_base
    container.mark_base.size_to_base
  end

  def have_source_raw_jpeg_controls?
    defined?(@source_raw_jpeg_static) && defined?(@source_raw_jpeg_combo)
  end

  def raw_jpeg_render_source
    src = "JPEG"
    if have_source_raw_jpeg_controls?
      src = "RAW" if @source_raw_jpeg_combo.get_selected_item == SOURCE_RAW_LABEL
    end
    src
  end
end

class U500pxBackgroundDataFetchWorker
  def initialize(bridge, dlg)
    @bridge = bridge
    @dlg = dlg
    @client = U500pxClient.new(@bridge)
  end

  # Do we need these two???
  #  def account
  #    @dlg.account
  #  end

  #  def configuration
  #  end

  def do_task
    return unless @dlg.account_parameters_dirty
    success = false
    acct = @dlg.current_account_settings
    if acct.nil?
      @dlg.set_status_text("Please select an account, or create one with the Connections button.")
    elsif ! acct.appears_valid?
      @dlg.set_status_text("Some account settings appear invalid or missing. Please click the Connections button.")
    else
      @dlg.set_status_text("You are logged in and ready to upload your images.")
    end
    @dlg.account_parameters_dirty = false
  end


end

class U500pxFileUploader
  include PM::FileUploaderTemplate
  include ImageProcessingControlsLogic
  include OperationsControlsLogic
  include RenamingControlsLogic
  include JpegSizeEstimationLogic
  include UpdateComboLogic
  include FormatBytesizeLogic
  include PreflightWaitAccountParametersLogic

  attr_accessor :account_parameters_dirty, :authenticated_protocol
  attr_reader :num_files, :ui

  DLG_SETTINGS_KEY = :upload_dialog

  def self.template_display_name
    TEMPLATE_DISPLAY_NAME
  end

  def self.template_description
    "Upload images to 500px"
  end

  def self.conn_settings_class
    U500pxConnectionSettings
  end

  def initialize(pm_api_bridge, num_files, dlg_status_bridge, conn_settings_serializer)
    @bridge = pm_api_bridge
    @num_files = num_files
    @dlg_status_bridge = dlg_status_bridge
    @conn_settings_ser = conn_settings_serializer
    @last_status_txt = nil
    @account_parameters_dirty = false
    @data_fetch_worker = nil
  end

  def upload_files(global_spec, progress_dialog)
    raise "upload_files called with no @ui instantiated" unless @ui
    acct = current_account_settings
    raise "Failed to load settings for current account. Please click the Connections button." unless acct
    spec = build_upload_spec(acct, @ui)

    # Expand metadata specification strings as set in the gui per image
    build_imagemetadata_spec(spec, ui)

    @bridge.kickoff_template_upload(spec, U500pxUploadProtocol)
  end

  def preflight_settings(global_spec)
    raise "preflight_settings called with no @ui instantiated" unless @ui

    acct = current_account_settings
    raise "Failed to load settings for current account. Please click the Connections button." unless acct
    raise "Some account settings appear invalid or missing. Please click the Connections button." unless acct.appears_valid?

    preflight_jpeg_controls
    preflight_wait_account_parameters_or_timeout

    build_upload_spec(acct, @ui)
  end

  def create_controls(parent_dlg)
    @ui = U500pxFileUploaderUI.new(@bridge)
    @ui.create_controls(parent_dlg)

    @ui.send_original_radio.on_click { adjust_controls }
    @ui.send_jpeg_radio.on_click { adjust_controls }

    @ui.dest_account_combo.on_sel_change { account_parameters_changed }

    add_jpeg_controls_event_hooks
    add_image_processing_controls_event_hooks
    add_operations_controls_event_hooks
    set_seqn_static_to_current_seqn

    @last_status_txt = nil

    create_data_fetch_worker
  end

  def layout_controls(container)
    @ui.layout_controls(container)
  end

  def destroy_controls
    destroy_data_fetch_worker
    @ui = nil
  end

  def reset_active_account
    account_parameters_changed
  end

  def selected_account
    @ui.dest_account_combo.get_selected_item_text
  end

  def save_state(serializer)
    return unless @ui
    serializer.store(DLG_SETTINGS_KEY, :selected_account, @ui.dest_account_combo.get_selected_item)
  end

  def restore_state(serializer)
    reset_account_combo_from_settings
    select_previous_account(serializer)
    select_first_available_if_present
    account_parameters_changed
    adjust_controls
  end

  def reset_account_combo_from_settings
    data = fetch_conn_settings_data
    @ui.dest_account_combo.reset_content( data.keys )
  end

  def select_previous_account(serializer)
    prev_selected_account = serializer.fetch(DLG_SETTINGS_KEY, :selected_account)
    @ui.dest_account_combo.set_selected_item(prev_selected_account) if prev_selected_account
  end

  def select_first_available_if_present
    if @ui.dest_account_combo.get_selected_item.empty?  &&  @ui.dest_account_combo.num_items > 0
      @ui.dest_account_combo.set_selected_item( @ui.dest_account_combo.get_item_at(0) )
    end
  end

  def periodic_timer_callback
    return unless @ui
    @data_fetch_worker.exec_messages
    handle_jpeg_size_estimation
  end

  def set_status_text(txt)
    if txt != @last_status_txt
      @dlg_status_bridge.set_text(txt)
      @last_status_txt = txt
    end
  end

  def update_account_combo_list
    data = fetch_conn_settings_data
    @ui.dest_account_combo.reset_content( data.keys )
  end

  def select_active_account
    selected_settings_name = U500pxConnectionSettings.fetch_selected_settings_name(@conn_settings_ser)
    if selected_settings_name
      @ui.dest_account_combo.set_selected_item( selected_settings_name )
    end

    # if selection didn't take, and we have items in the list, just pick the 1st one
    if @ui.dest_account_combo.get_selected_item.empty? &&  @ui.dest_account_combo.num_items > 0
      @ui.dest_account_combo.set_selected_item( @ui.dest_account_combo.get_item_at(0) )
    end
  end

  # Called by the framework after user has closed the Connection Settings dialog.
  def connection_settings_edited(conn_settings_serializer)
    @conn_settings_ser = conn_settings_serializer

    update_account_combo_list
    select_active_account
    account_parameters_changed
  end

  def authenticated_protocol
    unless @authenticated_protocol
      prot = nil
      begin

        prot = U500pxUploadProtocol.new(@bridge, {
                                          :connection_settings_serializer => @conn_settings_ser,
                                          :dialog => self
                                        })

        prot.authenticate_from_settings({
                                          :token => account.auth_token,
                                          :token_secret => account.auth_token_secret
                                        }) if tokens_present?

      rescue Exception => ex
        display_message_box "Unable to login to 500px server. Please click the Connections button.\nError: #{ex.message}"
        (prot.close if prot) rescue nil
        raise
      end
    end

    @authenticated_protocol ||= prot
  end

  def config
    authenticated_protocol.config
  end

  # account from settings data
  def account
    @account = current_account_settings
  end

  def account_valid?
    ! (account_empty? || account_invalid?)
  end

  def disable_ui
    # @ui.tweet_edit.enable(false)
    @ui.send_button.enable(false)
  end

  def imglink_button_spec
    { :filename => "logo.tif", :bgcolor => "ffffff" }
  end

  def imglink_url
    "https://www.500px.com/"
  end

  protected

  def create_data_fetch_worker
    qfac = lambda { @bridge.create_queue }
    @data_fetch_worker = BackgroundDataFetchWorkerManager.new(U500pxBackgroundDataFetchWorker, qfac, [@bridge, self])
  end

  def destroy_data_fetch_worker
    if @data_fetch_worker
      @data_fetch_worker.terminate
      @data_fetch_worker = nil
    end
  end

  def display_message_box(text)
    Dlg::MessageBox.ok(text, Dlg::MessageBox::MB_ICONEXCLAMATION)
  end

  def adjust_controls
    adjust_image_processing_controls
  end

  def build_upload_spec(acct, ui)
    spec = AutoStruct.new

    # string displayed in upload progress dialog title bar:
    spec.upload_display_name  = "500px.com:#{ui.dest_account_combo.get_selected_item}"
    # string used in logfile name, should have NO spaces or funky characters:
    spec.log_upload_type      = TEMPLATE_DISPLAY_NAME.tr('^A-Za-z0-9_-','')
    # account string displayed in upload log entries:
    spec.log_upload_acct      = spec.upload_display_name

    # Token and secret
    spec.token = authenticated_protocol.access_token
    spec.token_secret = authenticated_protocol.access_token_secret

    # FIXME: we're limiting concurrent uploads to 1 because
    #        end of queue notification happens per uploader thread
    #        and we can still be uploading, causing
    #        partially transmitted files get prematurely
    #        harvested on the server side
    spec.max_concurrent_uploads = 1

    spec.num_files = @num_files

    # NOTE: upload_queue_key should be unique for a given protocol,
    #       and a given upload "account".
    #       Rule of thumb: If file A requires a different
    #       login than file B, they should have different
    #       queue keys.
    spec.upload_queue_key = [
      "500px"
    ].join("\t")

    spec.upload_processing_type = ui.send_original_radio.checked? ? "originals_jpeg_only" : "save_as_jpeg"
    spec.send_incompatible_originals_as = "JPEG"
    spec.send_wav_files = false

    build_jpeg_spec(spec, ui)
    build_image_processing_spec(spec, ui)

    # spec.apply_stationery_pad = false
    # spec.preserve_exif = false
    # spec.save_transmitted_photos = false
    # spec.save_photos_subdir_type = 'specific'

    build_operations_spec(spec, ui)

    spec.do_rename = false
    # build_renaming_spec(spec, ui)

    spec
  end

  def convertGPS(gpscoordinate)
    gpscoordinate = gpscoordinate.strip
    if !gpscoordinate.empty?
      if !(gpscoordinate =~ /^[\d.+-]+$/).nil?
        gpscoordinate = gpscoordinate.to_f
      elsif !(gpscoordinate =~ /^[NESW]?\s*([\d.+-]+[°'′"″]){1,3}(\s*[NESW])?$/).nil?
        # Coordinates can be given as 
        angle  = 0
        gpscoordinate.scan(/([\d.+-]+)([°'′"″])/) { |n, denominator|
          n = n.to_f
          n /= 60 if denominator != '°' # Minutes or seconds
          n /= 60 if denominator == '"' || denominator == '″' # Seconds
          angle += n
        }
        angle *= (gpscoordinate =~ /[SW]/).nil? ? 1 : -1 # Negative numbers if coordinate in S or W
        gpscoordinate = "#{angle}"
      else
        dbgprint "Invalid GPS coordinate specification: #{gpscoordinate}"
        gpscoordinate = ""
      end
    end
    gpscoordinate
  end

  def build_imagemetadata_spec(spec, ui)
    metadata = {
      "category" => @ui.meta_category_combo.get_selected_item.to_i.to_s,
      "nsfw" => @ui.meta_nsfw_check.checked? ? "1" : "0",
      "license_type" => @ui.meta_license_type_combo.get_selected_item.to_i.to_s,
      "privacy" => @ui.meta_privacy_check.checked? ? "1" : "0"
    }
    # Setting taken_at currently not supported by 500px
    [ "name", "description", "shutter_speed", "focal_length", "aperture", "iso", "camera", "lens", "latitude", "longitude", "tags" ].each do |item|
      itemvalue = eval "@ui.meta_#{item}_edit.get_text"
      metadata[item] = itemvalue
    end
    spec.metadata = {}
    @num_files.times do |i|
      fname = @bridge.expand_vars("{folderpath}{filename}", i+1)
      unique_id = @bridge.get_item_unique_id(i+1) 
      spec.metadata[unique_id] = {}
      metadata.each_pair do |item, value|
        interpreted_value = @bridge.expand_vars(value, i+1)
        interpreted_value = convertGPS(interpreted_value) if !(item =~ /^(long|lat)itude$/).nil?
        spec.metadata[unique_id][item] = interpreted_value
      end
    end
  end
  
  def fetch_conn_settings_data
    U500pxConnectionSettings.fetch_settings_data(@conn_settings_ser)
  end

  def current_account_settings
    acct_name = @ui.dest_account_combo.get_selected_item
    data = fetch_conn_settings_data
    settings = data ? data[acct_name] : nil
  end

  def tokens_present?
    account && account.appears_valid?
  end

  def account_empty?
    if account.nil?
      notify_account_missing
      return true
    else
      return false
    end
  end

  def account_invalid?
    if account && account.appears_valid?
      return false
    else
      notify_account_invalid
      return true
    end
  end

  def notify_account_missing
    set_status_text("Please select an account, or create one with the Connections button.")
  end

  def notify_account_invalid
    set_status_text("You need to authorize your account.")
  end

  def account_parameters_changed
    @account = nil
    @account_parameters_dirty = true
  end
end

class U500pxCodeVerifierDialog < Dlg::DynModalChildDialog

  include PM::Dlg
  include CreateControlHelper

  attr_accessor :access_token, :access_token_secret, :name

  def initialize(api_bridge, client, dialog_end_callback)
    @bridge = api_bridge
    @access_token = nil
    @access_token_secret = nil
    @name = "Unknown"
    @client = client
    @dialog_end_callback = dialog_end_callback
    super()
  end

  def init_dialog
    dlg = self
    dlg.set_window_position_key("U500pxCodeVerifierDialogT")
    dlg.set_window_position(50, 200, 300, 160)
    title = "Verification code"
    dlg.set_window_title(title)

    create_control(:code_static,   Static,      dlg, :label=>"Enter the verification code:")
    create_control(:code_edit,     EditControl, dlg, :value=>"", :persist=>false)
    create_control(:submit_button, Button,      dlg, :label=>"Submit", :does=>"ok")
    create_control(:cancel_button, Button,      dlg, :label=>"Cancel", :does=>"cancel")

    @submit_button.on_click { get_access_token }
    @cancel_button.on_click { closebox_clicked }

    layout_controls
    instantiate_controls
    show(true)
  end

  def destroy_dialog!
    @dialog_end_callback.call(@access_token, @access_token_secret, @name) if @dialog_end_callback
    super
  end

  def layout_controls
    sh, eh = 20, 24

    dlg = self
    client_width, client_height = dlg.get_clientrect_size
    c = LayoutContainer.new(0, 0, client_width, client_height)
    c.inset(10, 20, -10, -5)

    c << @code_static.layout(0, c.base, -1, sh)
    c.pad_down(0).mark_base
    c << @code_edit.layout(0, c.base, -1, eh)
    c.pad_down(5).mark_base

    bw = 80
    c << @submit_button.layout(-(2*bw+3), -eh, bw, eh)
    c << @cancel_button.layout(-bw, -eh, bw, eh)
  end

  protected

  def code_value
    @code_edit.get_text.strip
  end

  def code_value_empty?
    code_value.empty?
  end

  def notify_code_value_blank
    Dlg::MessageBox.ok("Please enter a non-blank code.", Dlg::MessageBox::MB_ICONEXCLAMATION)
  end

  def get_access_token
    notify_code_value_blank and return if code_value_empty?

    begin
      oauth_verifier = code_value
      result = @client.get_access_token(oauth_verifier)
      store_access_settings(result)
    rescue StandardError => ex
      Dlg::MessageBox.ok("Failed to authorize with 500px. Error: #{ex.message}", Dlg::MessageBox::MB_ICONEXCLAMATION)
    ensure
      end_dialog(IDOK)
    end
  end

  def store_access_settings(result)
    @access_token, @access_token_secret, @name = result
  end
end

class U500pxClient
  BASE_URL = "https://api.500px.com/v1/"
  API_KEY = 'Vai22qxgGIIsdONIVkICLHsFAlGaP52GAYF0beK6'
  API_SECRET = '8ks0AuHKQUO2WEIxrAeBsFOMBgOHc13KdwCKRX4w'

  attr_accessor :access_token, :access_token_secret, :name
  attr_accessor :config

  def initialize(bridge, options = {})
    @bridge = bridge
    @authenticated = false
  end

  def reset!
    @access_token = nil
    @access_token_secret = nil
    @name = nil
  end

  def get_500px_authorization(callback)
    reset!
    fetch_request_token
    launch_500px_authorization_in_browser
    open_500px_entry_dialog(callback)
  end

  def fetch_request_token
    response = post('oauth/request_token')

    result = CGI::parse(response.body)
    
    @access_token = result['oauth_token']
    @access_token_secret = result['oauth_token_secret']
    @access_token
  end

  def launch_500px_authorization_in_browser
    fetch_request_token unless @access_token
    authorization_url = "https://api.500px.com/v1/oauth/authorize?oauth_token=#{@access_token}"
    @bridge.launch_url(authorization_url)
  end

  def open_500px_entry_dialog(callback)
    callback_a = lambda do |token, token_secret, name|
      store_settings_data(token, token_secret, name)
      callback.call(self)
      # update_ui
    end
    cdlg = U500pxCodeVerifierDialog.new(@bridge, self, callback_a)
    cdlg.instantiate!
    cdlg.request_deferred_modal
  end

  def get_access_token(verifier)
    @verifier = verifier
    response = post('oauth/access_token')
    result = CGI::parse(response.body)  
    @access_token = result['oauth_token']
    @access_token_secret = result['oauth_token_secret']

    raise "Unable to verify code" unless authenticated?

    # Now we get the name from the user record on 500px
    @verifier = nil
    response = get('users')
    require_server_success_response(response)
    response_body = JSON.parse(response.body)
    @name = "#{response_body['user']['username']} (#{response_body['user']['fullname']})"
    @verifier = verifier
    
    [ @access_token, @access_token_secret, @name ]
  end

  def authenticate_from_settings(settings = {})
    @access_token = settings[:token]
    @access_token_secret = settings[:token_secret]
    @name = settings[:name]
  end

  def update_ui
    @dialog.reset_active_account
  end

  def authenticated?
    !(@access_token.nil? || @access_token.empty? || @access_token_secret.nil? || @access_token_secret.empty?)
  end

  def store_settings_data(token, token_secret, name)
    @access_token = token
    @access_token_secret = token_secret
    @name = name
  end

  protected

  def request_headers(method, url, params = {}, signature_params = params)
    {'Authorization' => auth_header(method, url, params, signature_params)}
  end

  def auth_header(method, url, params = {}, signature_params = params)
    oauth_auth_header(method, url, signature_params).to_s
  end

  def oauth_auth_header(method, uri, params = {})
    uri = URI.parse(uri)
    SimpleOAuth::Header.new(method, uri, params, credentials)
  end

  def credentials
    {
      :consumer_key    => API_KEY,
      :consumer_secret => API_SECRET,
      :token           => @access_token,
      :token_secret    => @access_token_secret,
      :verifier        => @verifier,
      :callback        => 'http://www.hayobaan.nl/codeverifier.php'
    }
  end

  # todo: handle timeout
  def ensure_open_http(host, port)
    unless @http
      @http = @bridge.open_http_connection(host, port)
      @http.use_ssl = true
      @http.open_timeout = 60
      @http.read_timeout = 180
    end
  end

  def close_http
    if @http
      @http.finish rescue nil
      @http = nil
    end
  end

  def get(path, params = {})
    headers = request_headers(:get, BASE_URL + path, params, {})
    request(:get, path, params, headers)
  end

  def post(path, params = {}, upload_headers = {})
    uri = BASE_URL + path
    headers = request_headers(:post, uri, params, {})
    headers.merge!(upload_headers)
    request(:post, path, params, headers)
  end

  def request(method, path, params = {}, headers = {})
    url = BASE_URL + path
    uri = URI.parse(url)
    ensure_open_http(uri.host, uri.port)

    if method == :get
      @http.send(method.to_sym, uri.request_uri, headers)
    else
      @http.send(method.to_sym, uri.request_uri, params, headers)
    end
  end

  def require_server_success_response(resp)
    raise(RuntimeError, resp.inspect) unless resp.code == "200"
  end
end

class U500pxUploadProtocol
  BASE_URL = "https://api.500px.com/v1/"
  API_KEY = 'Vai22qxgGIIsdONIVkICLHsFAlGaP52GAYF0beK6'
  API_SECRET = '8ks0AuHKQUO2WEIxrAeBsFOMBgOHc13KdwCKRX4w'

  attr_reader :access_token, :access_token_secret
  attr_accessor :config

  def initialize(pm_api_bridge, options = {:connection_settings_serializer => nil, :dialog => nil})
    @bridge = pm_api_bridge
    @shared = @bridge.shared_data
    @http = nil
    @access_token = nil
    @access_token_secret = nil
    @dialog = options[:dialog]
    @connection_settings_serializer = options[:connection_settings_serializer]
    @config = nil
    mute_transfer_status
    close
  end

  def mute_transfer_status
    # we may make multiple requests while uploading a file, and
    # don't want the progress bar to jump around until we get
    # to the actual upload
    @mute_transfer_status = true
  end

  def close
    # close_http
  end

  def reset!
    @access_token = nil
    @access_token_secret = nil
  end

  def image_upload(local_filepath, remote_filename, is_retry, spec)
    @bridge.set_status_message "Uploading via secure connection..."

    @access_token = spec.token
    @access_token_secret = spec.token_secret

    upload(local_filepath, remote_filename, spec)

    @shared.mutex.synchronize {
      dat = (@shared[spec.upload_queue_key] ||= {})
      dat[:pending_uploadjob] ||= 0
      dat[:pending_uploadjob] += 1
    }

    remote_filename
  end

  def transfer_queue_empty(spec)
    @shared.mutex.synchronize {
      dat = (@shared[spec.upload_queue_key] ||= {})

      if dat[:pending_uploadjob].to_i > 0
        dat[:pending_uploadjob] = 0
      end
    }
  end

  def reset_transfer_status
    (h = @http) and h.reset_transfer_status
  end

  # return [bytes_to_write, bytes_written]
  def poll_transfer_status
    if (h = @http)  &&  ! @mute_transfer_status
      [h.bytes_to_write, h.bytes_written]
    else
      [0, 0]
    end
  end

  def abort_transfer
    (h = @http) and h.abort_transfer
  end

  def create_query_string( query_hash = {} )
    qstr = ""
    query_hash.each_pair do |key, value|
      qstr += (qstr.empty? ? "?" : "&")
      qstr += "#{key}=" + URI.escape(value.to_s)
    end
    qstr
  end

  def upload(fname, remote_filename, spec)
    metadata_qstr = create_query_string(spec.metadata[spec.unique_id])

    begin
      @mute_transfer_status = false
      # Post photos 500px api call to get upload_key & photo_id
      response = post('photos' + metadata_qstr)
      require_server_success_response(response)
      response_body = JSON.parse(response.body)
      upload_qstr = create_query_string(
        { "upload_key" => response_body["upload_key"],
          "photo_id" => response_body["photo"]["id"],
          "consumer_key" => API_KEY,
          "access_key" => spec.token
        })
      
      # Upload image to 500px
      fcontents = @bridge.read_file_for_upload(fname)
      mime = MimeMultipart.new
      mime.add_image("file", remote_filename, fcontents, "application/octet-stream")
      data, headers = mime.generate_data_and_headers
      # Note: this goes to domain upload.500px.com instead of the normal api.500px.com!
      url = 'https://upload.500px.com/v1/upload' + upload_qstr
      uri = URI.parse(url)
      ensure_open_http(uri.host, uri.port)
      response = @http.send(:post, uri.request_uri, data, headers)
      require_server_success_response(response)
      
    ensure
      @mute_transfer_status = true
    end
    return
  end

  def authenticate_from_settings(settings = {})
    @access_token = settings[:token]
    @access_token_secret = settings[:token_secret]
  end

  protected

  def request_headers(method, url, params = {}, signature_params = params)
    {'Authorization' => auth_header(method, url, params, signature_params)}
  end

  def auth_header(method, url, params = {}, signature_params = params)
    oauth_auth_header(method, url, signature_params).to_s
  end

  def oauth_auth_header(method, uri, params = {})
    uri = URI.parse(uri)
    SimpleOAuth::Header.new(method, uri, params, credentials)
  end

  def credentials
    {
      :consumer_key    => API_KEY,
      :consumer_secret => API_SECRET,
      :token           => @access_token,
      :token_secret    => @access_token_secret,
      :verifier => @verifier,
      :callback => 'http://www.hayobaan.nl/codeverifier.php'
    }
  end

  # todo: handle timeout
  def ensure_open_http(host, port)
    unless @http
      @http = @bridge.open_http_connection(host, port)
      @http.use_ssl = true
      @http.open_timeout = 60
      @http.read_timeout = 180
    end
  end

  def close_http
    if @http
      @http.finish rescue nil
      @http = nil
    end
  end

  def get(path, params = {})
    headers = request_headers(:get, BASE_URL + path, params, {})
    request(:get, path, params, headers)
  end

  def post(path, params = {}, upload_headers = {})
    uri = BASE_URL + path
    headers = request_headers(:post, uri, params, {})
    headers.merge!(upload_headers)
    request(:post, path, params, headers)
  end

  def request(method, path, params = {}, headers = {})
    url = BASE_URL + path
    uri = URI.parse(url)
    ensure_open_http(uri.host, uri.port)

    if method == :get
      @http.send(method.to_sym, uri.request_uri, headers)
    else
      @http.send(method.to_sym, uri.request_uri, params, headers)
    end
  end

  def require_server_success_response(resp)
    raise(RuntimeError, resp.inspect) unless resp.code == "200"
  end
end

class U500pxConfiguration
  attr_accessor :image_size_limit, :link_char_count, :max_images

  def self.from_response(response_body)
    if response_body['errors']
      response_body
    else
      image_size_limit = response_body['photo_size_limit']
      link_char_count = response_body['short_url_length_https']
      max_images = response_body['max_media_per_upload']

      new({
            :image_size_limit => image_size_limit,
            :link_char_count => link_char_count,
            :max_images => max_images
          })
    end
  end

  def initialize(args = {})
    @image_size_limit ||= args[:image_size_limit]
    @link_char_count ||= args[:link_char_count]
    @max_images ||= args[:max_images]
  end
end
