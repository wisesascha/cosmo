class CrudScaffoldingSandbox
  include ActionView::Helpers::ActiveRecordHelper

  attr_accessor :form_action, :singular_name, :suffix, :model_instance

  def sandbox_binding
    binding
  end

  def default_input_block
    Proc.new { |record, column| "  <tr>\n    <th><label for=\"#{record}_#{column.name}\">#{column.human_name}:</label></th>\n    <td>#{input(record, column.name, :limit => column.limit)}</td>\n  </tr>"}
  end
end

class ActionView::Helpers::InstanceTag
  def to_input_field_tag(field_type, options={})
    "<%= #{field_type}_field('#{@object_name}', '#{@method_name}' #{options.empty? ? '' : ', '+options.inspect}) %>"
  end

  def to_text_area_tag(options = {})
    "<%= text_area('#{@object_name}', '#{@method_name}' #{options.empty? ? '' : ', '+ options.inspect}) %>"
  end

  def to_date_select_tag(options = {})
    "<%= date_select('#{@object_name}', '#{@method_name}' #{options.empty? ? '' : ', '+ options.inspect}) %>"
  end

  def to_datetime_select_tag(options = {})
    "<%= datetime_select('#{@object_name}', '#{@method_name}' #{options.empty? ? '' : ', '+ options.inspect}) %>"
  end
  
  def to_time_select_tag(options = {})
    "<%= time_select('#{@object_name}', '#{@method_name}' #{options.empty? ? '' : ', '+ options.inspect}) %>"
  end
end

class CrudScaffoldGenerator < Rails::Generator::NamedBase

  attr_reader   :controller_name,
                :controller_class_path,
                :controller_file_path,
                :controller_class_nesting,
                :controller_class_nesting_depth,
                :controller_class_name,
                :controller_singular_name,
                :controller_plural_name
  alias_method  :controller_file_name,  :controller_singular_name
  alias_method  :controller_table_name, :controller_plural_name

  def initialize(runtime_args, runtime_options = {})
    super

    # Take controller name from the next argument.  Default to the pluralized model name.
    @controller_name = args.shift
    @controller_name ||= ActiveRecord::Base.pluralize_table_names ? @name.pluralize : @name

    base_name, @controller_class_path, @controller_file_path, @controller_class_nesting, @controller_class_nesting_depth = extract_modules(@controller_name)
    @controller_class_name_without_nesting, @controller_singular_name, @controller_plural_name = inflect_names(base_name)

    if @controller_class_nesting.empty?
      @controller_class_name = @controller_class_name_without_nesting
    else
      @controller_class_name = "#{@controller_class_nesting}::#{@controller_class_name_without_nesting}"
    end
  end

  def manifest
    record do |m|
      # Check for class naming collisions.
      m.class_collisions controller_class_path, "#{controller_class_name}Controller", "#{controller_class_name}ControllerTest", "#{controller_class_name}Helper"

      # Controller, helper, views, and test directories.
      m.directory File.join('app/controllers', controller_class_path)
      m.directory File.join('app/helpers', controller_class_path)
      m.directory File.join('app/views', controller_class_path, controller_file_name)
      m.directory File.join('app/views/layouts', controller_class_path)
      m.directory File.join('test/functional', controller_class_path)

      # Depend on model generator but skip if the model exists.
      m.dependency 'model', [singular_name], :collision => :skip, :skip_migration => true

      # Scaffolded forms.
      m.complex_template "form.html.erb",
        File.join('app/views',
                  controller_class_path,
                  controller_file_name,
                  "_form.html.erb"),
        :insert => 'form_scaffolding.html.erb',
        :sandbox => lambda { create_sandbox },
        :begin_mark => 'form',
        :end_mark => 'eoform',
        :mark_id => singular_name


      # Scaffolded views.
      scaffold_views.each do |action|
        m.template "view_#{action}.html.erb",
                   File.join('app/views',
                             controller_class_path,
                             controller_file_name,
                             "#{action}.html.erb"),
                   :assigns => { :action => action }
      end

      # Controller class, functional test, helper, and views.
      m.template 'controller.rb',
                  File.join('app/controllers',
                            controller_class_path,
                            "#{controller_file_name}_controller.rb")

      m.template 'functional_test.rb',
                  File.join('test/functional',
                            controller_class_path,
                            "#{controller_file_name}_controller_test.rb")

      m.template 'helper.rb',
                  File.join('app/helpers',
                            controller_class_path,
                            "#{controller_file_name}_helper.rb")

      # Layout and stylesheet.
      m.template 'layout.html.erb',
                  File.join('app/views/layouts',
                            controller_class_path,
                            "#{controller_file_name}.html.erb")

      m.template 'style.css', 'public/stylesheets/crud_scaffold.css'


      # Unscaffolded views.
      unscaffolded_actions.each do |action|
        path = File.join('app/views',
                          controller_class_path,
                          controller_file_name,
                          "#{action}.html.erb")
        m.template "controller:view.html.erb", path,
                   :assigns => { :action => action, :path => path}
      end
    end
  end

  protected
    # Override with your own usage banner.
    def banner
      "Usage: #{$0} scaffold ModelName [ControllerName] [action, ...]"
    end

    def scaffold_views
      %w(list show new edit)
    end

    def scaffold_actions
      scaffold_views + %w(index create update destroy)
    end

    def model_name 
      class_name.demodulize
    end

    def unscaffolded_actions
      args - scaffold_actions
    end

    def suffix
      "_#{singular_name}" if options[:suffix]
    end

    def create_sandbox
      sandbox = CrudScaffoldingSandbox.new
      sandbox.singular_name = singular_name
      begin
        sandbox.model_instance = model_instance
        sandbox.instance_variable_set("@#{singular_name}", sandbox.model_instance)
      rescue ActiveRecord::StatementInvalid => e
        logger.error "Before updating scaffolding from new DB schema, try creating a table for your model (#{class_name}) named #{class_name.tableize}."
        raise SystemExit
      end
      sandbox.suffix = suffix
      sandbox
    end

    def model_instance
      base = class_nesting.split('::').inject(Object) do |base, nested|
        break base.const_get(nested) if base.const_defined?(nested)
        base.const_set(nested, Module.new)
      end
      unless base.const_defined?(@class_name_without_nesting)
        base.const_set(@class_name_without_nesting, Class.new(ActiveRecord::Base))
      end
      class_name.constantize.new
    end
end
