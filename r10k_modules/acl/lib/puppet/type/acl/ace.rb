# frozen_string_literal: true

require 'puppet/parameter/value_collection'
require 'pathname'

class Puppet::Type::Acl
  # Ace is an Access Control Entry for use with the Access
  # Control List (ACL) type. ACEs contain information about
  # the trustee, the rights, and on some systems how they are
  # inherited and propagated to subtypes.
  class Ace < Hash
    # < Hash is due to a bug with how Puppet::Resource.to_manifest
    # does not work through quite the same code and needs to
    # believe this custom object is a Hash. If issues are later
    # found, this should be reviewed.
    require "#{Pathname.new(__FILE__).dirname}/../../../puppet/type/acl/rights"

    attr_reader :identity
    attr_reader :rights, :perm_type, :child_types, :affects, :is_inherited, :mask

    def initialize(permission_hash, provider = nil)
      super()

      @provider = provider
      id = permission_hash['identity']
      id = permission_hash['id'] if id.nil? || id.empty?
      self.identity = id
      self.id = permission_hash['id']
      @mask = permission_hash['mask']
      self.rights = permission_hash['rights']
      self.perm_type = permission_hash['perm_type']
      if permission_hash['type']
        Puppet.deprecation_warning('Permission `type` is deprecated and has been replaced with perm_type for allow or deny')
        if permission_hash['perm_type'] && permission_hash['type'] != permission_hash['perm_type']
          raise ArgumentError, "Can not accept both `type` => #{permission_hash['type']} and `perm_type` => #{permission_hash['perm_type']}"
        end

        self.perm_type = permission_hash['type']
      end
      self.child_types = permission_hash['child_types']
      self.affects = permission_hash['affects']
      @is_inherited = permission_hash['is_inherited'] || false
      @hash = nil
    end

    # Checks if a supplied value matches an allowed set of values.
    #
    # @param [Object] value
    # @param [Array] allowed_values
    # @return [Object] Return supplied value if it matches.
    def validate(value, *allowed_values)
      validator = Puppet::Parameter::ValueCollection.new
      validator.newvalues(*allowed_values)
      validator.validate(value)

      value
    end

    # Returns value of is_inherited
    #
    # @return [Boolean] Value of is_inherited
    def inherited?
      is_inherited
    end

    # Converts a value into a symbol
    #
    # @param [Object] value Object to convert
    # @return [Symbol] Symbol of object
    def convert_to_symbol(value)
      return nil if value.nil? || value.empty?
      return value if value.is_a?(Symbol)

      value.downcase.to_sym
    end

    # Checks if a supplied value is non empty
    #
    # @param name Name of value used for logging an error
    # @param [Object] value Value to validate
    # @return [Object] Supplied value if it is non empty.
    def validate_non_empty(name, value)
      raise ArgumentError, "A non-empty #{name} must be specified." if value.nil? || value == ''
      raise ArgumentError, "Value for #{name} should have least one element in the array." if value.is_a?(Array) && value.count.zero?

      value
    end

    # Checks if a supplied value is an array and returns it.
    #
    # @param [Object] values Value to validate
    # @return [Object] Supplied value if it is an array.
    def validate_array(name, values)
      raise ArgumentError, "Value for #{name} should be an array. Perhaps try ['#{values}']?" unless values.is_a?(Array)

      values
    end

    # Checks if a supplied set of values matches an allowed set of values.
    #
    # @param [Array] values
    # @param [Array] allowed_values
    # @return [Array] Returns supplied values if they all match.
    def validate_individual_values(values, *allowed_values)
      values.each do |value|
        validate(value, *allowed_values)
      end

      values
    end

    # Converts an array of values to symbols.
    #
    # @param [Array] values Array of strings.
    # @return [Array] Converted symbols `values`.
    def convert_to_symbols(values)
      value_syms = []
      values.each do |value|
        value_syms << convert_to_symbol(value)
      end

      value_syms
    end

    # Converts an array of symbols into strings.
    #
    # @param [Array] symbols Array of symbols.
    # @return [Array] Converted strings of `symbols`.
    def convert_from_symbols(symbols)
      values = []
      symbols.each do |value|
        values << value.to_s
      end

      values
    end

    # Returns `rights` sorted in reverse order
    #
    # @return [Object] Sorted rights
    def ensure_rights_order
      @rights.sort_by! { |r| Puppet::Type::Acl::Rights.new(r).order }
    end

    # Ensures the values of `rights` are valid
    # An error is raised if a condition is invalid.
    def ensure_rights_values_compatible
      if @rights.include?(:mask_specific) && rights.count != 1
        raise ArgumentError, "In each ace, when specifying rights, if you include 'mask_specific', it should be without anything else e.g. rights => ['mask_specific']. Please decide whether 'mask_specific' or predetermined rights and correct the manifest. Reference: #{inspect}" # rubocop:disable Layout/LineLength
      end

      if @rights.include?(:full) && rights.count != 1
        Puppet.warning("In each ace, when specifying rights, if you include 'full', it should be without anything else e.g. rights => ['full']. Please remove the extraneous rights from the manifest to remove this warning. Reference: #{inspect}") # rubocop:disable Layout/LineLength
        @rights = [:full]
      end
      if @rights.include?(:modify) && rights.count != 1 # rubocop:disable Style/GuardClause  Changing this to a guard clause makes the line long and unreadable
        Puppet.warning("In each ace, when specifying rights, if you include 'modify', it should be without anything else e.g. rights => ['modify']. Please remove the extraneous rights from the manifest to remove this warning. Reference: #{inspect}") # rubocop:disable Layout/LineLength
        @rights = [:modify]
      end
    end

    # Ensures that `mask` is set to `value` when `rights` is set to `mask_specific`.
    # An error is raised if the condition is not matched.
    def ensure_mask_when_mask_specific
      if @rights.include?(:mask_specific) && (@mask.nil? || @mask.empty?) # rubocop:disable Style/GuardClause  Changing this to a guard clause makes the line long and unreadable
        raise ArgumentError, "If you specify rights => ['mask_specific'], you must also include mask => 'value'. Reference: #{inspect}"
      end
    end

    # Checks that a supplied array of values are unique.
    #
    # @param [Array] values
    # @return [Array] Return `values` with unique values else return `values`.
    def ensure_unique_values(values)
      return values.uniq if values.is_a?(Array)

      values
    end

    # Ensures valid usage of `child_types` and `affects`.
    # A `Puppet.warning` is raised if incorrect usage is found.
    def ensure_none_or_self_only_sync
      return if @child_types.nil? || @affects.nil?
      return if @child_types == :none && @affects == :self_only
      return unless @child_types == :none || @affects == :self_only

      if @child_types == :none && (@affects != :all && @affects != :self_only)
        Puppet.warning("If child_types => 'none', affects => value will be ignored. Please remove affects or set affects => 'self_only' to remove this warning. Reference: #{inspect}")
      end
      @affects = :self_only if @child_types == :none

      if @affects == :self_only && (@child_types != :all && @child_types != :none)
        Puppet.warning("If affects => 'self_only', child_types => value will be ignored. Please remove child_types or set child_types => 'none' to remove this warning. Reference: #{inspect}")
      end
      @child_types = :none if @affects == :self_only
    end

    # Sets value of `identity`.
    #
    # @param [Object] value Should be non-empty
    def identity=(value)
      @identity = validate_non_empty('identity', value)
      @hash = nil
    end

    # Retrieves value of `id`
    #
    # @return [Object] SID of ACE
    def id
      @id = @provider.get_account_id(@identity) if (@id.nil? || @id.empty?) && (@identity && @provider && @provider.respond_to?(:get_account_id))

      @id
    end

    # Sets value of `id`.
    #
    # @param [Object] value
    def id=(value)
      @id = value
      @hash = nil
    end

    # Sets value of `rights`.
    #
    # @param [Array] value Array of rights
    def rights=(value)
      @rights = ensure_unique_values(
        convert_to_symbols(
          validate_individual_values(
            validate_array(
              'rights',
              validate_non_empty('rights', value),
            ),
            :full, :modify, :write, :read, :execute, :mask_specific
          ),
        ),
      )
      ensure_rights_order
      ensure_rights_values_compatible
      ensure_mask_when_mask_specific if @rights.include?(:mask_specific)
      @hash = nil
    end

    # Sets value of `mask`.
    #
    # @param [Object] value
    def mask=(value)
      @mask = value
      @hash = nil
    end

    # Sets value of `perm_type`.
    #
    # @param [Object] value
    def perm_type=(value)
      @perm_type = convert_to_symbol(validate(value || :allow, :allow, :deny))
      @hash = nil
    end

    # Sets value of `child_types`.
    #
    # @param [Object] value
    def child_types=(value)
      @child_types = convert_to_symbol(validate(value || :all, :all, :objects, :containers, :none))
      ensure_none_or_self_only_sync
      @hash = nil
    end

    # Sets value of `affects`.
    #
    # @param [Object] value
    def affects=(value)
      @affects = convert_to_symbol(validate(value || :all, :all, :self_only, :children_only, :self_and_direct_children_only, :direct_children_only))
      ensure_none_or_self_only_sync
      @hash = nil
    end

    # Used as part of the `same?` method to determine if the current ACE is the same as a supplied ACE
    #
    # @param [Ace] other ACE to compare to
    # @return [Array] IDs of the supplied ACEs
    def get_comparison_ids(other = nil)
      ignore_other = true
      id_has_value = false
      other_id_has_value = false
      other_id = nil

      unless other.nil?
        ignore_other = false
        other_id_has_value = true unless other.id.nil? || other.id.empty?
      end

      id_has_value = true unless id.nil? || id.empty?

      if id_has_value && (ignore_other || other_id_has_value)
        id = self.id
        other_id = other.id unless ignore_other
      elsif @provider.respond_to?(:get_account_name)
        id = @provider.get_account_name(@identity)
        other_id = @provider.get_account_name(other.identity) unless ignore_other
      else
        id = @identity
        other_id = other.identity unless ignore_other
      end

      [id, other_id]
    end

    # This ensures we are looking at the same ace even if the
    # rights are different. Contextually we have two ace objects
    # and we are trying to determine if they are the same ace or
    # different given all of the different compare points.
    #
    # @param [Ace] other The ace that we are comparing to.
    # @return [Boolean] True if all points are equal
    def same?(other)
      return false unless other.is_a?(Ace)

      account_ids = get_comparison_ids(other)

      account_ids[0] == account_ids[1] &&
        @child_types == other.child_types &&
        @affects == other.affects &&
        @is_inherited == other.is_inherited &&
        @perm_type == other.perm_type
    end

    # This ensures we are looking at the same ace with the same
    # rights. We want to know if the two aces are equal on all
    # important data points.
    #
    # @param [Ace] other The ace that we are comparing to.
    # @return [Boolean] True if all points are equal
    def ==(other)
      return false unless other.is_a?(Ace)

      same?(other) &&
        @rights == other.rights
    end

    alias eql? ==

    # Returns hash of instance's fields
    #
    # @return [Hash] Hash of instance fields
    def hash
      [get_comparison_ids[0],
       @rights,
       @perm_type,
       @child_types,
       @affects,
       is_inherited].hash
    end

    # Returns hash of instance's fields
    #
    # @return [Hash] Hash of instance fields
    def to_hash
      return @hash if @hash

      ace_hash = {}
      ace_hash['identity'] = identity
      ace_hash['rights'] = convert_from_symbols(rights)
      ace_hash['mask'] = mask if rights == [:mask_specific] && !mask.nil?
      ace_hash['perm_type'] = perm_type unless perm_type == :allow || perm_type.nil?
      ace_hash['child_types'] = child_types unless child_types == :all || child_types == :none || child_types.nil?
      ace_hash['affects'] = affects unless affects == :all || affects.nil?
      ace_hash['is_inherited'] = is_inherited if is_inherited

      @hash = ace_hash
      @hash
    end

    # The following methods: keys, values, [](key) make
    # `puppet resource acl somelocation` believe that
    # this is actually a Hash and can pull the values
    # from this object.
    def keys
      to_hash.keys
    end

    # Returns values of instance fields
    #
    # @return [Array] Values of fields from hash
    def values
      to_hash.values
    end

    # Returns value of specified key in instance fields hash.
    #
    # @param [String] key Key used to get value from hash.
    # @return [Object] Value of field.
    def [](key)
      to_hash[key]
    end

    # Returns string representation of instance's fields.
    #
    # @return [String] String of instance hash.
    def inspect
      hash = to_hash
      return_value = hash.keys.map { |key|
        key_value = hash[key]
        if key_value.is_a? Array
          "#{key} => #{key_value}"
        else
          "#{key} => '#{key_value}'"
        end
      }.join(', ')

      "\n { #{return_value} }"
    end

    alias to_s inspect

    # added to support Ruby 2.3 which serializes Hashes differently when
    # writing YAML than previous Ruby versions, which can break the last
    # run report or corrective changes reports due to attempts to
    # serialize the attached provider
    def encode_with(coder)
      # produce a set of plain key / value pairs by removing the "tag"
      # by setting it to nil, producing YAML serialization like
      # "---\nidentity: Administrators\nrights:\n- full\n"
      # with the tag set to its default value, serialization appears like
      # "--- !ruby/object:Puppet::Type::Acl::Ace\nidentity: Administrators\nrights:\n- full\n"
      coder.represent_map nil, to_hash

      # rubocop:disable Layout/LineLength
      # without this method implemented, serialization varies based on Ruby version like:
      # Ruby 2.3
      # "--- !ruby/hash-with-ivars:Puppet::Type::Acl::Ace\nelements: {}\nivars:\n  :@provider: \n  :@identity: Administrators\n  :@hash: \n  :@id: S-32-12-0\n  :@mask: '2023422'\n  :@rights:\n  - :full\n  :@perm_type: :allow\n  :@child_types: :all\n  :@affects: :all\n  :@is_inherited: false\n"
      # Ruby 2.1.9
      # "--- !ruby/hash:Puppet::Type::Acl::Ace {}\n"
      # rubocop:enable Layout/LineLength
    end
  end
end
