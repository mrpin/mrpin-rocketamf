require 'spec_helper.rb'

describe AMF::Ext::FastClassMapping do
  before :each do
    AMF::Ext::FastClassMapping.reset
    AMF::Ext::FastClassMapping.define do |m|
      m.map :as => 'ASClass', ruby: 'ClassMappingTest'
    end
    @mapper = AMF::Ext::FastClassMapping.new
  end

  describe 'class name mapping' do
    it 'should allow resetting of mappings back to defaults' do
      @mapper.get_class_name_remote('ClassMappingTest').should_not be_nil
      AMF::Ext::FastClassMapping.reset
      @mapper = AMF::Ext::FastClassMapping.new
      @mapper.get_class_name_remote('ClassMappingTest').should be_nil
    end

    it 'should return AS class name for ruby objects' do
      @mapper.get_class_name_remote(ClassMappingTest.new).should == 'ASClass'
      @mapper.get_class_name_remote('ClassMappingTest').should == 'ASClass'
      @mapper.get_class_name_remote(AMF::Types::HashWithType.new('ClassMappingTest')).should == 'ASClass'
      @mapper.get_class_name_remote('BadClass').should be_nil
    end

    it 'should instantiate a ruby class' do
      @mapper.create_object('ASClass').should be_a(ClassMappingTest)
    end

    it 'should properly instantiate namespaced classes' do
      AMF::Ext::FastClassMapping.map.map :as => 'ASClass', ruby: 'ANamespace::TestRubyClass'
      @mapper = AMF::Ext::FastClassMapping.new
      @mapper.create_object('ASClass').should be_a(ANamespace::TestRubyClass)
    end

    it 'should return a hash with original type if not mapped' do
      obj = @mapper.create_object('UnmappedClass')
      obj.should be_a(AMF::Types::HashWithType)
      obj.class_type.should == 'UnmappedClass'
    end

    it 'should map special classes from AS by default' do
      as_classes =
          %w(
              flex.messaging.messages.CommandMessage
              flex.messaging.messages.RemotingMessage
            )

      as_classes.each do |as_class|
        @mapper.create_object(as_class).should_not be_a(AMF::Types::HashWithType)
      end
    end

    it 'should map special classes from ruby by default' do
      ruby_classes =
          %w(
              AMF::Types::ErrorMessage
            )

      ruby_classes.each do |obj|
        @mapper.get_class_name_remote(obj).should_not be_nil
      end
    end

    it 'should allow config modification' do
      AMF::Ext::FastClassMapping.map.map :as => 'SecondClass', ruby: 'ClassMappingTest'
      @mapper = AMF::Ext::FastClassMapping.new
      @mapper.get_class_name_remote(ClassMappingTest.new).should == 'SecondClass'
    end
  end

  describe 'ruby object populator' do
    it 'should populate a ruby class' do
      obj = @mapper.object_deserialize ClassMappingTest.new, {:prop_a => 'Data'}
      obj.prop_a.should == 'Data'
    end

    it 'should populate a typed hash' do
      obj = @mapper.object_deserialize AMF::Types::HashWithType.new('UnmappedClass'), {'prop_a' => 'Data'}
      obj['prop_a'].should == 'Data'
    end
  end

  describe 'property extractor' do
    # Use symbol keys for properties in Ruby >1.9
    def prop_hash hash
      out = {}
      if RUBY_VERSION =~ /^1\.8/
        hash.each { |k, v| out[k.to_s] = v }
      else
        hash.each { |k, v| out[k.to_sym] = v }
      end
      out
    end

    it 'should return hash without modification' do
      hash  = {:a => 'test1', 'b' => 'test2'}
      props = @mapper.object_serialize(hash)
      props.should === hash
    end

    it 'should extract object properties' do
      obj        = ClassMappingTest.new
      obj.prop_a = 'Test A'

      hash = @mapper.object_serialize obj
      hash.should == prop_hash({'prop_a' => 'Test A', 'prop_b' => nil})
    end

    it 'should extract inherited object properties' do
      obj        = ClassMappingTest2.new
      obj.prop_a = 'Test A'
      obj.prop_c = 'Test C'

      hash = @mapper.object_serialize obj
      hash.should == prop_hash({'prop_a' => 'Test A', 'prop_b' => nil, 'prop_c' => 'Test C'})
    end

    it 'should cache property lookups by instance' do
      class ClassMappingTest3;
        attr_accessor :prop_a;
      end;

      # Cache properties
      obj  = ClassMappingTest3.new
      hash = @mapper.object_serialize obj

      # Add a method to ClassMappingTest3
      class ClassMappingTest3;
        attr_accessor :prop_b;
      end

      # Test property list does not have new property
      obj        = ClassMappingTest3.new
      obj.prop_a = 'Test A'
      obj.prop_b = 'Test B'
      hash       = @mapper.object_serialize obj
      hash.should == prop_hash({'prop_a' => 'Test A'})

      # Test that new class mapper *does* have new property (cache per instance)
      @mapper = AMF::Ext::FastClassMapping.new
      hash    = @mapper.object_serialize obj
      hash.should == prop_hash({'prop_a' => 'Test A', 'prop_b' => 'Test B'})
    end
  end
end