module CSVParty
  module DSL
    RESERVED_COLUMN_NAMES = [:unparsed,
                             :csv_string,
                             :row_number,
                             :skip_message,
                             :abort_message].freeze

    def column(column, options = {}, &block)
      raise_if_duplicate_column(column)
      raise_if_reserved_column_name(column)

      options = {
        header: column_regex(column),
        as: :string,
        format: nil,
        intercept_blanks: (options[:as] != :raw)
      }.merge(options)

      parser = if block_given?
                 block
               else
                 "#{options[:as]}_parser".to_sym
               end

      @_columns[column] = {
        header: options[:header],
        parser: parser,
        format: options[:format],
        intercept_blanks: options[:intercept_blanks]
      }
    end

    def rows(&block)
      @_row_importer = block
    end

    def import(&block)
      @_file_importer = block
    end

    def errors(setting = nil, &block)
      @_error_handler = setting || block
    end

    def skipped_rows(setting = nil, &block)
      @_skipped_row_handler = setting || block
    end

    def aborted_rows(setting = nil, &block)
      @_aborted_row_handler = setting || block
    end

    def depends_on(*args)
      args.each do |arg|
        dependencies << arg
        attr_accessor arg
      end
    end

    def dependencies
      @_dependencies ||= []
    end

    def columns
      @_columns ||= {}
    end

    def row_importer
      @_row_importer ||= nil
    end

    def file_importer
      @_file_importer ||= nil
    end

    def error_handler
      @_error_handler ||= nil
    end

    def skipped_row_handler
      @_skipped_row_handler ||= nil
    end

    def aborted_row_handler
      @_aborted_row_handler ||= nil
    end

    private

    def column_regex(column)
      column = Regexp.escape(column.to_s)
      underscored_or_whitespaced = "#{column}|#{column.tr('_', ' ')}"
      /\A\s*#{underscored_or_whitespaced}\s*\z/i
    end

    def raise_if_duplicate_column(name)
      return unless columns.has_key?(name)

      raise DuplicateColumnError.new(name)
    end

    def raise_if_reserved_column_name(column)
      return unless RESERVED_COLUMN_NAMES.include? column

      raise ReservedColumnNameError.new(RESERVED_COLUMN_NAMES)
    end
  end
end