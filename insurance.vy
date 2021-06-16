# @version ^0.2.0

# Request insurance for delivery person who suffered an accident during working hours

# ------------------------------------ #
#               VARIABLES              #
# ------------------------------------ #

# Delivery person basic informations
struct DeliveryPerson:
    delivery_count: uint256
    last_working_month: uint256
    family_account: address
    on_leave: bool
    months_on_leave: uint256
    return_month: bool
    is_registered: bool

# Dictionary with all delivery people
delivery_people: public(HashMap[address, DeliveryPerson])

# Informations to request insurance refund
struct Request:
    requester: address
    value: uint256
    request_time: uint256
    accident_time: uint256
    accident_hour: uint256
    accident_type: uint256
    bill: bytes32
    approved: bool
    closed: bool

# Dictionary with all requests
requests: public(HashMap[uint256, Request])

# Counter for request id
request_counter: uint256

# Contract owner
owner: address

# Fund amount
fund_total_amount: uint256


# ------------------------------------ #
#               FUNCTIONS              #
# ------------------------------------ #

# Setup global variables when contract is deployed
@external
@payable
def __init__():
    self.owner = msg.sender
    self.request_counter = 0
    self.fund_total_amount = msg.value


# Register new delivery person
@external
def register_new_delivery_person(family_account: address):

    assert not self.delivery_people[msg.sender].is_registered, "Delivery person already registered."

    self.delivery_people[msg.sender] = DeliveryPerson({
                                                        delivery_count: 0,
                                                        last_working_month: 0,
                                                        family_account: family_account,
                                                        on_leave: False,
                                                        months_on_leave: 0,
                                                        return_month: False,
                                                        is_registered: True
                                                     })


# Update the delivery count for each delivery person every month
@external
@payable
def update_delivery_count(delivery_person: address, delivery_count: uint256):

    assert self.owner == msg.sender, "Only the project owner can update the delivery count."

    assert self.delivery_people[delivery_person].is_registered, "Delivery person not registered."

    assert msg.value > 0, "Missing value."

    if self.delivery_people[delivery_person].on_leave:
        self.delivery_people[delivery_person].months_on_leave = self.delivery_people[delivery_person].months_on_leave - 1
        if self.delivery_people[delivery_person].months_on_leave <= 0:
            self.delivery_people[delivery_person].is_registered = False

    else: 
        if self.delivery_people[delivery_person].return_month:
            self.delivery_people[delivery_person].return_month = False
        else:
            self.delivery_people[delivery_person].delivery_count = delivery_count
    
    self.delivery_people[delivery_person].last_working_month = self.delivery_people[delivery_person].last_working_month + 1
    self.fund_total_amount = self.fund_total_amount + msg.value


# Unregister delivery person
@external
def unregister():

    assert self.delivery_people[msg.sender].is_registered, "Delivery person not registered."

    self.delivery_people[msg.sender].is_registered = False


# Unregister delivery person
@internal
def unregister_delivery_person(request_id: uint256):

    assert self.delivery_people[self.requests[request_id].requester].is_registered, "Delivery person not registered."

    if self.requests[request_id].accident_type > 2:
        self.delivery_people[self.requests[request_id].requester].is_registered = False


# Accident types:
# [0] minor (no leave)
# [1] mild (1 month leave)
# [2] medium (2 months leave)
# [3] severe (3 months leave)
# [4] disablement (stop working)
# [5] passing (stop working)

# Request insurance
@external
def request_refund(
                    requested_value: uint256,
                    accident_time: uint256,
                    accident_hour: uint256, 
                    accident_type: uint256, 
                    bill: bytes32
                  ):

    assert self.delivery_people[msg.sender].is_registered, "Delivery person not registered."

    assert self.delivery_people[msg.sender].on_leave == False, "Delivery person already on leave."

    assert requested_value > 0, "Invalid value."

    assert accident_hour >= 0 and accident_hour <= 24, "Invalid accident hour."

    assert accident_type >= 0 and accident_type <= 5, "Invalid accident type."

    self.requests[self.request_counter] = Request({
                                                    requester: msg.sender,
                                                    value: requested_value,
                                                    request_time: block.timestamp,
                                                    accident_time: accident_time,
                                                    accident_hour: accident_hour,
                                                    accident_type: accident_type,
                                                    bill: bill,
                                                    approved: False,
                                                    closed: False
                                                  })

    self.request_counter = self.request_counter + 1


# Refund insurance amount
@internal
def refund(request_id: uint256):
    
    assert self.balance >= self.requests[request_id].value, "Critical! There's not enough money in the fund."

    amount: uint256 = 0

    if self.requests[request_id].accident_type > 2:
        amount = 100000
        if self.requests[request_id].value < amount:
            amount = self.requests[request_id].value
        if self.requests[request_id].accident_type == 4:
            send(self.delivery_people[self.requests[request_id].requester].family_account, amount)

        self.unregister_delivery_person(request_id)

    else:
        amount = 15000
        if self.requests[request_id].value < amount:
            amount = self.requests[request_id].value
        send(self.requests[request_id].requester, amount)

        self.delivery_people[self.requests[request_id].requester].on_leave = True
        self.delivery_people[self.requests[request_id].requester].months_on_leave = self.requests[request_id].accident_type       

    self.fund_total_amount = self.fund_total_amount - amount

# Analyze refund request
@external
def analyze_request(request_id: uint256, approved: bool):

    assert msg.sender == self.owner, "Only the project owner can analyze a request."

    assert self.requests[request_id].closed == False, "Request already closed."

    assert self.delivery_people[self.requests[request_id].requester].on_leave == False, "Delivery person already on leave."

    assert self.requests[request_id].accident_time + 31556926 >= self.requests[request_id].request_time, "Refund request was not made within 1 year after the accident." 

    # Working hours: 7AM - 2AM, with 1 hour range to get to work and to go back home
    assert self.requests[request_id].accident_hour < 3 or self.requests[request_id].accident_hour > 6, "Accident didn't happened during working hours."

    if self.delivery_people[self.requests[request_id].requester].last_working_month > 2:
        assert self.delivery_people[self.requests[request_id].requester].delivery_count >= 100, "Minimum of 100 deliveries not reached."

    self.requests[request_id].approved = approved
    self.requests[request_id].closed = True
    self.refund(request_id)


# Return from leave
@external
def return_from_leave():

    assert self.delivery_people[msg.sender].is_registered, "Delivery person not registered."

    assert self.delivery_people[msg.sender].on_leave == True, "Delivery person not on leave."

    assert self.delivery_people[msg.sender].months_on_leave <= 0, "Still on leave."

    self.delivery_people[msg.sender].return_month = True
    self.delivery_people[msg.sender].on_leave = False


# Add up more money to fund
@external
@payable
def add_up_fund():

    assert msg.sender == self.owner, "Only the contract owner can add up on fund."

    assert msg.value > 0, "Missing value."

    self.fund_total_amount = self.fund_total_amount + msg.value
