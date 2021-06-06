# @version ^0.2.0

# Request insurance for delivery person who suffered an accident during working hours

# ------------------------------------ #
#               VARIABLES              #
# ------------------------------------ #

struct Request:
    requester: address
    value: uint256
    transport: uint256
    request_time: uint256
    accident_time: uint256
    approved: bool

requests: HashMap[uint256, Request]

# Contract owner
owner: address

# Counter for request id
request_counter: uint256


# ------------------------------------ #
#               FUNCTIONS              #
# ------------------------------------ #

@external
def __init__():
    self.owner = msg.sender
    self.request_counter = 0


# Request insurance
# Transport options:
# [1] - motorbike
# [2] - bicycle
# [3] - on foot
@external
@payable
def request_refund(transport: uint256, accident_time: uint256):

    self.requests[self.request_counter] = Request({
                                                    requester: msg.sender,
                                                    value: msg.value,
                                                    transport: transport,
                                                    request_time: block.timestamp,
                                                    accident_time: accident_time,
                                                    approved: False
                                                  })

    self.request_counter = self.request_counter + 1


@external
def refund(request_id: uint256):

    send(self.requests[request_id].requester, self.requests[request_id].value)