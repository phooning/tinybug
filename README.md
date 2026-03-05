# tinybug

Ever wanted to be your own CIA agent? Now, it's possible to collect the same intelligence on yourself as the deep state always intended.

**Currently testing on... iOS.** Uses `startMonitoringSignificantLocationChanges()` to constantly track your whereabouts every cell tower switch, sending back phone, location, and any other data you want to track to a secure endpoint of your choice.

On the server side, ensure you have it running on a port. I recommend securely going through Tailscale or a VPS.

### Roadmap

- [ ] Build out server-side ingestion point
- [ ] Support PC devices via Rust binary
- [ ] LLM inference pipeline: behavioral patterns, networks, geospatial insight
- [ ] Globally viewable map plot

## Get Started

### Sender

1. Load the `xcodeproj` file.
2. Build the project onto your iPhone.

### Receiver

3. Clone the project on your receiver computer.
4. Start the server.

## Data Points

- Device identifier (hashed IMSI/IMEI/phone ID)
- Timestamp
- Latitude/longitude
- Cell tower ID
- Movement velocity
- Device type
- Network identifiers
