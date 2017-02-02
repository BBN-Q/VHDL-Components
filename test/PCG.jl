module PCG

import Base: rand
export PCGenerator

type PCGenerator
    state::UInt64
    offset::UInt64
end

PCGenerator(state=0) = PCGenerator(state, 2531011)

function rand(g::PCGenerator)
    oldstate = g.state
    # LCG step to advance internal state
    g.state = 6364136223846793005 * g.state + g.offset
    # calculate output function (XSH RR)
    xorshifted = (((oldstate >>> 18) $ oldstate) >>> 27) % UInt32
    rot = (oldstate >>> 59) % UInt32
    return (xorshifted >>> rot) | (xorshifted << ((-rot) & 31))
end

end
