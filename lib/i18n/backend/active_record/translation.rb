require 'active_record'

module I18n
  module Backend
    # ActiveRecord model used to store actual translations to the database.
    #
    # This model expects a table like the following to be already set up in
    # your the database:
    #
    #   create_table :translations do |t|
    #     t.string :locale
    #     t.string :key
    #     t.text   :value
    #     t.text   :interpolations
    #     t.boolean :is_proc, :default => false
    #   end
    #
    # This model supports to named scopes :locale and :lookup. The :locale
    # scope simply adds a condition for a given locale:
    #
    #   I18n::Backend::ActiveRecord::Translation.locale(:en).all
    #   # => all translation records that belong to the :en locale
    #
    # The :lookup scope adds a condition for looking up all translations
    # that either start with the given keys (joined by an optionally given
    # separator or I18n.default_separator) or that exactly have this key.
    #
    #   # with translations present for :"foo.bar" and :"foo.baz"
    #   I18n::Backend::ActiveRecord::Translation.lookup(:foo)
    #   # => an array with both translation records :"foo.bar" and :"foo.baz"
    #
    #   I18n::Backend::ActiveRecord::Translation.lookup([:foo, :bar])
    #   I18n::Backend::ActiveRecord::Translation.lookup(:"foo.bar")
    #   # => an array with the translation record :"foo.bar"
    #
    class ActiveRecord
      class Translation < ::ActiveRecord::Base
        self.table_name = 'translations'
        attr_accessible :locale, :key, :value

        serialize :value
        serialize :interpolations, Array

        class << self
          def locale(locale)
            scoped(:conditions => { :locale => locale.to_s })
          end

          def lookup(keys, *separator)
            column_name = connection.quote_column_name('key')
            keys = Array(keys).map { |key| key.to_s }

            unless separator.empty?
              warn "[DEPRECATION] Giving a separator to Translation.lookup is deprecated. " <<
                "You can change the internal separator by overwriting FLATTEN_SEPARATOR."
            end

            namespace = "#{keys.last}#{I18n::Backend::Flatten::FLATTEN_SEPARATOR}%"
            scoped(:conditions => ["#{column_name} IN (?) OR #{column_name} LIKE ?", keys, namespace])
          end

          def available_locales
            Translation.select('DISTINCT locale').all.map { |t| t.locale.to_sym }
          end
        end

        def interpolates?(key)
          self.interpolations.include?(key) if self.interpolations
        end
      end
    end
  end
end

