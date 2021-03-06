require "test_helper"

class PreferencesForm < OnForm::Form
  expose %i(name email phone_number friendly), on: :customer

  def initialize(customer)
    @customer = customer
  end
end

class PreferencesFormWithFormValidations < PreferencesForm
  validates :name, length: { maximum: 10 }
end

describe "a basic single-model form" do
  before do
    Customer.delete_all
    @customer = Customer.create!(name: "Test User", email: "test@example.com", phone_number: "123-4567")
    @preferences_form = PreferencesForm.new(@customer)
  end

  it "doesn't allow access to un-exposed attributes" do
    proc { @preferences_form.created_at }.must_raise(NoMethodError)
    proc { @preferences_form.verified }.must_raise(NoMethodError)
    proc { @preferences_form.verified = true }.must_raise(NoMethodError)
  end

  it "returns exposed attribute values from attribute reader methods" do
    @preferences_form.name.must_equal "Test User"
  end

  it "sets exposed attribute values from attribute writer methods" do
    @customer.name_changed?.must_equal false
    @preferences_form.name = "New Name"
    @customer.name.must_equal "New Name"
    @customer.name_was.must_equal "Test User"
    @customer.name_changed?.must_equal true
  end

  it "lists attribute names" do
    # expect strings back for compatibility with ActiveRecord
    @preferences_form.attribute_names.sort.must_equal %w(name email phone_number friendly).sort
  end

  it "returns all attributes in a hash from attributes" do
    @preferences_form.attributes.must_equal({"name" => "Test User", "email" => "test@example.com", "phone_number" => "123-4567", "friendly" => true})
  end

  it "sets exposed attribute values from mass assignment to attributes=" do
    @preferences_form.attributes = {name: "New Name"}
    @customer.name.must_equal "New Name"
  end

  it "rejects nil assignments to attributes= with ArgumentError rather than a nil dereference" do
    proc { @preferences_form.attributes = nil }.must_raise(ArgumentError)
  end

  it "saves written attribute values" do
    @preferences_form.name = "New Name 1"
    @preferences_form.save!
    @customer.reload.name.must_equal "New Name 1"

    @preferences_form.update!(name: "New Name 2")
    @customer.reload.name.must_equal "New Name 2"
  end

  it "returns false from valid? if a validation fails" do
    @preferences_form.valid?.must_equal true
    @preferences_form.email = nil
    @preferences_form.valid?.must_equal false
  end

  it "raises ActiveRecord::RecordInvalid from save! or update! if a record validation fails" do
    proc { @preferences_form.update!(email: nil) }.must_raise(ActiveRecord::RecordInvalid)
    proc { @preferences_form.save! }.must_raise(ActiveRecord::RecordInvalid)
  end

  it "returns false from save or update if a record validation fails" do
    @preferences_form.update(email: nil).must_equal false
    @preferences_form.save.must_equal false
  end

  it "exposes record validation errors on attributes" do
    @preferences_form.email = nil
    @preferences_form.save.must_equal false
    @preferences_form.errors.full_messages.must_equal ["Email can't be blank"]
    @preferences_form.errors[:email].must_equal ["can't be blank"]

    begin
      @preferences_form.name = ""
      @preferences_form.save!
      fail
    rescue ActiveRecord::RecordInvalid
      @preferences_form.errors.full_messages.sort.must_equal ["Email can't be blank", "Name can't be blank"]
      @preferences_form.errors[:name].must_equal ["can't be blank"]
    end
  end

  it "raises ActiveModel::ValidationError from save! or update! if a form validation fails" do
    @preferences_form = PreferencesFormWithFormValidations.new(@customer)
    proc { @preferences_form.update!(name: "a"*11) }.must_raise(ActiveModel::ValidationError)
    proc { @preferences_form.save! }.must_raise(ActiveModel::ValidationError)
  end

  it "doesn't raise validation errors if save! is passed validate: false" do
    @preferences_form = PreferencesFormWithFormValidations.new(@customer)
    @preferences_form.name = "a"*11
    @preferences_form.save!(validate: false)
    @customer.reload.name.must_equal "a"*11
  end

  it "returns false from save or update if a form validation fails" do
    @preferences_form = PreferencesFormWithFormValidations.new(@customer)
    @preferences_form.update(name: "a"*11).must_equal false
    @preferences_form.save.must_equal false
  end

  it "doesn't run validations or return false from save when passed validate: false" do
    @preferences_form = PreferencesFormWithFormValidations.new(@customer)
    @preferences_form.name = "a"*11
    @preferences_form.save(validate: false).must_equal true
    @customer.reload.name.must_equal "a"*11
  end

  it "adds both record and form validation errors if both fail" do
    @preferences_form = PreferencesFormWithFormValidations.new(@customer)
    proc { @preferences_form.update!(email: nil, name: "a"*11) }.must_raise(ActiveModel::ValidationError)
    proc { @preferences_form.save! }.must_raise(ActiveModel::ValidationError)

    @preferences_form.errors[:name].must_equal ["is too long (maximum is 10 characters)"]
    @preferences_form.errors[:email].must_equal ["can't be blank"]
    @preferences_form.errors.full_messages.must_equal ["Name is too long (maximum is 10 characters)", "Email can't be blank"]
  end

  it "exposes validation errors on base" do
    @preferences_form.friendly?.must_equal true
    @preferences_form.friendly = false
    @preferences_form.save.must_equal false
    @preferences_form.errors.full_messages.must_equal ["Customer needs to be friendly"]
    @preferences_form.errors[:base].must_equal ["Customer needs to be friendly"]
  end
end
