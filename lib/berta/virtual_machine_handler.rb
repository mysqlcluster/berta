module Berta
  # Class for Berta operations on virtual machines
  class VirtualMachineHandler
    attr_reader :handle

    def initialize(vm)
      @handle = vm
    end

    # Sets notified into USER_TEMPLATE on virtual machine
    #
    # @note This method modifies OpenNebula database
    # @raise [BackendError] if connection to service failed
    def update_notified
      Berta::Utils::OpenNebula::Helper.handle_error \
        { handle.update("NOTIFIED = #{Time.now.to_i}", true) }
      handle.info
    end

    # @return [Numeric] Time when notified was set else nil.
    #   Time is in UNIX epoch time format.
    def notified
      time = handle['USER_TEMPLATE/NOTIFIED']
      time.to_i if time
    end

    # @return [Boolean] If this vm should be notified
    def should_notify?
      return false if notified
      expiration = default_expiration
      return false unless expiration
      expiration.in_notification_interval?
    end

    # Adds schelude action to virtual machine. This command
    #   modifies USER_TEMPLATE of virtual machine. But does
    #   not delete old variables is USER_TEMPLATE.
    #
    # @param [Numeric] Time when to notify user
    # @param [String] Action to perform on given time
    def add_expiration(time, action)
      template = \
        Berta::Entities::Expiration.new(next_sched_action_id,
                                        time,
                                        action).template
      expirations.each { |exp| template += exp.template }
      Berta::Utils::OpenNebula::Helper.handle_error \
        { handle.update(template, true) }
      handle.info
    end

    # Sets array of expirations to vm, rewrites all old ones.
    #   Receiving empty array wont change anything.
    #
    # @param [Array<Expiration>] Expirations to use
    def update_expirations(exps)
      template = ''
      exps.each { |exp| template += exp.template }
      Berta::Utils::OpenNebula::Helper.handle_error \
        { handle.update(template, true) }
      handle.info
    end

    # Returns array of expirations on vm
    #
    # @return [Array<Expiration>] All expirations on vm
    def expirations
      exps = []
      handle.each('USER_TEMPLATE/SCHED_ACTION') \
        { |saxml| exps.push(Berta::Entities::Expiration.from_xml(saxml)) }
      exps
    end

    # Return default expiration, that means expiration with
    #   default expiration action that is in expiration offset interval
    #   and is closes to current date
    #
    # @return [Expiration] nearest default expiration
    def default_expiration
      expirations
        .find_all { |exp| exp.default_action? && exp.in_expiration_interval? }
        .min { |exp| exp.time.to_i }
    end

    # Return name of virtual machine
    #
    # @return [String] name of virtual machine
    def name
      handle['NAME']
    end

    private

    def next_sched_action_id
      elems = handle.retrieve_elements('USER_TEMPLATE/SCHED_ACTION/ID')
      return 0 unless elems
      elems.to_a.max.to_i + 1
    end
  end
end
