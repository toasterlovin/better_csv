require 'csv_party/parsers'
require 'csv_party/validations'
require 'csv_party/errors'
require 'csv_party/row'

module CSVParty
  class Runner
    include Parsers
    include Validations

    attr_accessor :csv, :config, :importer

    def initialize(csv, config, importer)
      self.csv = csv
      self.config = config
      self.importer = importer
      @_rows_have_been_imported = false
      @_current_row_number = 1
    end

    def import!
      raise_unless_row_processor_is_defined!
      raise_unless_all_named_parsers_exist!
      raise_unless_all_dependencies_are_present!
      initialize_csv!
      initialize_regex_headers!
      raise_unless_csv_has_all_columns!

      if config.file_importer
        instance_exec(&config.file_importer)
        raise_unless_rows_have_been_imported!
      else
        import_rows!
      end

      return true
    rescue AbortedImportError => error
      importer.aborted = true
      importer.abort_message = error.message
      return false
    end

    def present_columns
      @_headers
    end

    def missing_columns
      config.required_columns - present_columns
    end

    private

    def initialize_csv!
      csv.shift
      @_headers = csv.headers
      csv.rewind
    end

    def initialize_regex_headers!
      config.columns_with_regex_headers.each do |name, options|
        found_header = @_headers.find do |header|
          options[:header].match(header)
        end
        options[:header] = found_header || name.to_s
      end
    end

    def import_rows!
      loop do
        begin
          csv_row = csv.shift
          break unless csv_row
          import_row!(csv_row)
        rescue CSV::MalformedCSVError
          raise
        end
      end

      @_rows_have_been_imported = true
    end

    def import_row!(csv_row)
      @_current_row_number += 1
      @_current_parsed_row = Row.new(csv_row, self)
      @_current_parsed_row.row_number = @_current_row_number

      instance_exec(@_current_parsed_row, &config.row_importer)
    rescue NextRowError
      return
    rescue SkippedRowError => error
      handle_skipped_row(error)
    rescue AbortedRowError => error
      handle_aborted_row(error)
    rescue AbortedImportError
      raise
    rescue StandardError => error
      handle_error(error, @_current_row_number, csv_row.to_csv)
    end

    def next_row!
      raise NextRowError
    end

    def skip_row!(message = nil)
      raise SkippedRowError, message
    end

    def abort_row!(message = nil)
      raise AbortedRowError, message
    end

    def abort_import!(message)
      raise AbortedImportError, message
    end

    def handle_error(error, line_number, csv_string)
      raise error unless config.error_handler

      if config.error_handler == :ignore
        error_rows << error_struct(error, line_number, csv_string)
      else
        instance_exec(error, line_number, csv_string, &config.error_handler)
      end
    end

    def handle_skipped_row(error)
      return if config.skipped_row_handler == :ignore

      @_current_parsed_row[:skip_message] = error.message

      if config.skipped_row_handler.nil?
        importer.skipped_rows << @_current_parsed_row
      else
        instance_exec(@_current_parsed_row, &config.skipped_row_handler)
      end
    end

    def handle_aborted_row(error)
      return if config.aborted_row_handler == :ignore

      @_current_parsed_row[:abort_message] = error.message

      if config.aborted_row_handler.nil?
        importer.aborted_rows << @_current_parsed_row
      else
        instance_exec(@_current_parsed_row, &config.aborted_row_handler)
      end
    end

    def error_struct(error, line_number, csv_string)
      Struct.new(:error, :line_number, :csv_string)
            .new(error, line_number, csv_string)
    end

    def named_parsers
      (methods +
       private_methods +
       importer.methods +
       importer.private_methods).grep(/^parse_/)
    end

    def respond_to_missing?(method, _include_private)
      importer.respond_to?(method, true)
    end

    def method_missing(method, *args)
      if importer.respond_to?(method, true)
        importer.send(method, *args)
      else
        super
      end
    end

    class NextRowError < Error
    end

    class SkippedRowError < Error
    end

    class AbortedRowError < Error
    end

    class AbortedImportError < Error
    end
  end
end
