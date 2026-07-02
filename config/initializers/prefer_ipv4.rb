# Prefer IPv4 for outbound TCP connections.
#
# Some networks advertise IPv6 (AAAA) records for external hosts (e.g.
# openrouter.ai) but the IPv6 route is broken. Ruby's Net::HTTP tries the
# IPv6 addresses first and waits out the full TCP connect timeout (~75s per
# address) before falling back to IPv4, which made every LLM call hang for
# minutes. curl works because it uses Happy Eyeballs; Ruby < 3.4 does not.
#
# resolv-replace makes TCPSocket resolve hostnames through Resolv, which
# returns A (IPv4) records first — so connections go straight to IPv4.
require "resolv-replace"
