advertise useful features in README?
advertise on the tavern?
add alerts and more messages from elsewhere

talisman pickup system where
it evaluates the talisman compared to the talismans in your inventory
if it's equal or strictly worse than any talisman in your inventory then return false to not pick it up
otherwise return nothing for "no opinion"
strictly worse means
the other talisman has a positive artifact property which it does not
and it has no negative artifact properties which it doesn't have
at the start of each turn, you should drop talismans which are strictly worse than any other talisman
