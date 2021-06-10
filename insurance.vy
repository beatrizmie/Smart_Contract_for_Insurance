# @version ^0.2.0

# Request insurance for delivery person who suffered an accident during working hours

# ------------------------------------ #
#               VARIABLES              #
# ------------------------------------ #

# Delivery person basic informations
struct DeliveryPerson:
    delivery_count: uint256
    fund_total_amount: uint256
    last_working_month: uint256
    family_account: address
    on_leave: bool
    registered: bool

# Dictionary with all delivery people
delivery_people: public(HashMap[address, DeliveryPerson])

# Informations to request insurance refund
struct Request:
    requester: address
    value: uint256
    request_time: uint256
    accident_time: uint256
    accident_type: uint256
    bill: bytes32
    approved: bool

# Dictionary with all requests
requests: public(HashMap[uint256, Request])

# Counter for request id
request_counter: uint256

# Contract owner
owner: address


# ------------------------------------ #
#               FUNCTIONS              #
# ------------------------------------ #

# Setup global variables when contract is deployed
@external
@payable
def __init__():
    self.owner = msg.sender
    self.request_counter = 0


# Register new delivery person
@external
def register_new_delivery_person(family_account: address):

    assert not self.delivery_people[msg.sender].registered, "Delivery person already registered."

    self.delivery_people[msg.sender] = DeliveryPerson({
                                                        delivery_count: 0,
                                                        fund_total_amount: 0,
                                                        last_working_month: 0,
                                                        family_account: family_account,
                                                        on_leave: False,
                                                        registered: True
                                                     })


# Update the delivery count for each delivery person every month
@external
@payable
def update_delivery_count(delivery_person: address, delivery_count: uint256):

    assert self.owner == msg.sender, "Only the project owner can update the delivery count."

    assert self.delivery_people[delivery_person].registered, "Delivery person not registered."

    assert msg.value > 0, "Missing value."

    self.delivery_people[delivery_person].last_working_month = self.delivery_people[delivery_person].last_working_month + 1
    self.delivery_people[delivery_person].delivery_count = delivery_count
    self.delivery_people[delivery_person].fund_total_amount = self.delivery_people[delivery_person].fund_total_amount + msg.value


# Unregister delivery person
@external
def unregister():

    assert self.delivery_people[msg.sender].registered, "Delivery person not registered."

    self.delivery_people[msg.sender].registered = False


# Unregister delivery person
@internal
def unregister_delivery_person(request_id: uint256):

    assert self.delivery_people[self.requests[request_id].requester].registered, "Delivery person not registered."

    if self.requests[request_id].accident_type > 2:
        self.delivery_people[self.requests[request_id].requester].registered = False


# Request insurance
# Accident types:
# [0] mild (1 month leave)
# [1] medium (2 months leave)
# [2] severe (3 months leave)
# [3] disablement (stop working)
# [4] passing (stop working)
@external
@payable
def request_refund(accident_time: uint256, accident_type: uint256, bill: bytes32):

    assert not msg.sender == self.owner, "Only delivery people can request refund."

    assert self.delivery_people[msg.sender].registered, "Delivery person not registered."

    assert msg.value > 0, "Missing value."

    assert accident_type >= 0, "Invalid accident type."
    assert accident_type < 5, "Invalid accident type."

    if self.delivery_people[msg.sender].last_working_month > 2:
        assert self.delivery_people[msg.sender].delivery_count >= 100, "Minimum of 100 deliveries not reached."

    self.requests[self.request_counter] = Request({
                                                    requester: msg.sender,
                                                    value: msg.value,
                                                    request_time: block.timestamp,
                                                    accident_time: accident_time,
                                                    accident_type: accident_type,
                                                    bill: bill,
                                                    approved: False
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


# Analyze refund request
@external
def analyze_request(request_id: uint256, approved: bool):

    assert msg.sender == self.owner, "Only the project owner can analyze a request."

    self.requests[request_id].approved = approved

    if self.requests[request_id].approved:
        self.refund(request_id)
