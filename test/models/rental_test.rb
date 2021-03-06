require 'test_helper'
require 'pry'

class RentalTest < ActiveSupport::TestCase
  let(:rental_data) {
    {
      checkout_date: "2017-01-08:",
      due_date: Date.today + 1,
      customer: customers(:one),
      movie: movies(:one)
    }
  }

  before do
    @rental = Rental.new(rental_data)
  end

  describe "Constructor" do
    it "Has a constructor" do
      Rental.create!(rental_data)
    end

    it "Has a customer" do
      @rental.must_respond_to :customer
    end

    it "Cannot be created without a customer" do
      data = rental_data.clone()
      data.delete :customer
      c = Rental.new(data)
      c.valid?.must_equal false
      c.errors.messages.must_include :customer
    end

    it "Has a movie" do
      @rental.must_respond_to :movie
    end

    it "Cannot be created without a movie" do
      data = rental_data.clone
      data.delete :movie
      c = Rental.new(data)
      c.valid?.must_equal false
      c.errors.messages.must_include :movie
    end
  end

  describe "due_date" do
    it "Cannot be created without a due_date" do
      data = rental_data.clone
      data.delete :due_date
      c = Rental.new(data)
      c.valid?.must_equal false
      c.errors.messages.must_include :due_date
    end

    it "due_date on a new rental must be in the future" do
      data = rental_data.clone
      data[:due_date] = Date.today - 1
      c = Rental.new(data)
      c.valid?.must_equal false
      c.errors.messages.must_include :due_date

      # Today is also not in the future
      data = rental_data.clone
      data[:due_date] = Date.today
      c = Rental.new(data)
      c.valid?.must_equal false
      c.errors.messages.must_include :due_date
    end

    it "rental with an old due_date can be updated" do
      r = Rental.find(rentals(:overdue).id)
      r.returned = true
      r.save!
    end
  end

  describe "first_outstanding" do
    it "returns the only un-returned rental" do
      Rental.count.must_equal 1
      Rental.first.returned.must_equal false
      Rental.first_outstanding(Rental.first.movie, Rental.first.customer).must_equal Rental.first
    end

    it "returns nil if no rentals are un-returned" do
      Rental.all.each do |rental|
        rental.returned = true
        rental.save!
      end
      Rental.first_outstanding(Rental.first.movie, Rental.first.customer).must_be_nil
    end

    it "prefers rentals with earlier due dates" do
      # Start with a clean slate
      Rental.destroy_all

      last = Rental.create!(
        movie: movies(:one),
        customer: customers(:one),
        due_date: Date.today + 30,
        returned: false
      )
      first = Rental.create!(
        movie: movies(:one),
        customer: customers(:one),
        due_date: Date.today + 10,
        returned: false
      )
      middle = Rental.create!(
        movie: movies(:one),
        customer: customers(:one),
        due_date: Date.today + 20,
        returned: false
      )
      Rental.first_outstanding(
        movies(:one),
        customers(:one)
      ).must_equal first
    end

    it "ignores returned rentals" do
      # Start with a clean slate
      Rental.destroy_all

      returned = Rental.create!(
        movie: movies(:one),
        customer: customers(:one),
        due_date: Date.today + 10,
        returned: true
      )
      outstanding = Rental.create!(
        movie: movies(:one),
        customer: customers(:one),
        due_date: Date.today + 30,
        returned: false
      )

      Rental.first_outstanding(
        movies(:one),
        customers(:one)
      ).must_equal outstanding
    end
  end

  describe "overdue" do
    it "returns all overdue rentals" do
      Rental.count.must_equal 1
      Rental.first.returned.must_equal false
      Rental.first.due_date.must_be :<, Date.today

      overdue = Rental.overdue
      overdue.length.must_equal 1
      overdue.first.must_equal Rental.first
    end

    it "ignores rentals that aren't due yet" do
      Rental.create!(
        movie: movies(:two),
        customer: customers(:one),
        due_date: Date.today + 10,
        returned: false
      )

      overdue = Rental.overdue
      overdue.length.must_equal 1
      overdue.first.must_equal Rental.first
    end

    it "ignores rentals that have been returned" do
      Rental.new(
        movie: movies(:two),
        customer: customers(:one),
        due_date: Date.today - 3,
        returned: true
      ).save!(validate: false)

      overdue = Rental.overdue
      overdue.length.must_equal 1
      overdue.first.must_equal Rental.first
    end

    it "returns an empty array if no rentals are overdue" do
      r = Rental.first
      r.returned = true
      r.save!
      Rental.overdue.length.must_equal 0
    end
  end

  describe "returned" do
    it "returns all returned rentals" do
      # Start with a clean slate
      Rental.destroy_all

      outstanding = Rental.create!(
        movie: movies(:one),
        customer: customers(:one),
        due_date: Date.today + 30,
        returned: false
      )
      Rental.new(
        movie: movies(:one),
        customer: customers(:one),
        due_date: Date.today - 10,
        returned: true
      ).save!(validate: false)

      second = Rental.create!(
        movie: movies(:one),
        customer: customers(:two),
        due_date: Date.today + 10,
        returned: true
      )
      Rental.returned.length.must_equal 2
      Rental.returned.last.must_equal second
      Rental.all.count.must_equal 3
    end
  end

  describe "out_ok" do
    it "returns all outstanding rentals that aren't due yet" do
      # Start with a clean slate
      Rental.destroy_all

      first = Rental.create!(
        movie: movies(:one),
        customer: customers(:one),
        due_date: Date.today + 10,
        returned: false
      )
      second = Rental.create!(
        movie: movies(:one),
        customer: customers(:two),
        due_date: Date.today + 20,
        returned: false
      )
      returned = Rental.create!(
        movie: movies(:two),
        customer: customers(:two),
        due_date: Date.today + 10,
        returned: true
      )
      Rental.new(
        movie: movies(:two),
        customer: customers(:one),
        due_date: Date.today - 30,
        returned: false
      ).save!(validate: false)
      Rental.out_ok.length.must_equal 2
      Rental.out_ok.first.must_equal first
      Rental.all.count.must_equal 4
    end

    it "considers today's date as not yet overdue" do
      # Start with a clean slate
      Rental.destroy_all

      Rental.new(
        movie: movies(:one),
        customer: customers(:one),
        due_date: Date.today,
        returned: false
      ).save!(validate: false)
      Rental.out_ok.length.must_equal 1
      Rental.all.count.must_equal 1
    end
  end

  describe "all rentals" do
    it "all rentals = overdue + returned + out_ok" do
      # Start with a clean slate
      Rental.destroy_all

      out_ok = Rental.create!(
        movie: movies(:one),
        customer: customers(:one),
        due_date: Date.today + 10,
        returned: true
      )
      # Overdue rental:
      Rental.new(
        movie: movies(:one),
        customer: customers(:two),
        due_date: Date.today - 10,
        returned: false
      ).save!(validate: false)
      returned_due_later = Rental.create!(
        movie: movies(:two),
        customer: customers(:two),
        due_date: Date.today + 10,
        returned: true
      )
      # Returned rental due in the past:
      Rental.new(
        movie: movies(:two),
        customer: customers(:one),
        due_date: Date.today - 10,
        returned: true
      ).save!(validate: false)
      expected_count = (Rental.overdue.length + Rental.returned.length + Rental.out_ok.length)
      Rental.all.count.must_equal expected_count
    end
  end

end
