# WAS-110 XGS-PON Netdata Plugin

A Netdata external plugin for monitoring BFW Solutions WAS-110 XGS-PON SFP+ modules running the 8311 community firmware.

## Overview

This plugin monitors critical metrics from your WAS-110 "fiber stick" including:
- **PLOAM State**: XGS-PON connection status and state transitions
- **Optical Power**: RX/TX power levels with quality assessment
- **Temperature**: Optic module and CPU temperatures
- **Electrical**: Module voltage and TX bias current
- **Connection Uptime**: Time in operational state (O5)
- **State Transitions**: Counters for connection events

## Features

- Real-time monitoring with 2-second updates
- Signal quality percentage based on RX power thresholds
- PLOAM state transition logging and counting
- Connection uptime tracking
- Graceful error handling for device unavailability
- Configurable thresholds for different fiber installations

## Prerequisites

### FreeBSD Requirements
```bash
# Install Python 3 and pip if not already installed
pkg install python39 py39-pip

# Install required Python packages
pip install requests urllib3
```

### WAS-110 Requirements
- WAS-110 running 8311 community firmware v2.8.2+
- API endpoint accessible at `https://192.168.11.1/cgi-bin/luci/8311/metrics`
- HTTP Basic Auth credentials (default: root/8311)

## Installation

### 1. Install Plugin Files
```bash
# Copy plugin to Netdata plugins directory
sudo cp was110.plugin /usr/libexec/netdata/plugins.d/
sudo chmod +x /usr/libexec/netdata/plugins.d/was110.plugin

# Copy configuration file
sudo cp was110.conf /etc/netdata/
sudo chown netdata:netdata /etc/netdata/was110.conf
```

### 2. Configure Plugin
Edit `/etc/netdata/was110.conf`:
```ini
[global]
url = https://192.168.11.1/cgi-bin/luci/8311/metrics
username = root
password = your_password_here
update_every = 2

[thresholds]
# Adjust these based on your fiber installation
rx_power_excellent = -21
rx_power_good = -25
rx_power_acceptable = -27
rx_power_poor = -30
```

### 3. Test Plugin
```bash
# Test standalone (Ctrl+C to stop)
sudo -u netdata /usr/libexec/netdata/plugins.d/was110.plugin 2

# Test API connectivity
./was110-test.sh
```

### 4. Enable in Netdata
Add to `/usr/local/etc/netdata/netdata.conf`:
```ini
[plugins]
    was110 = yes
```

### 5. Restart Netdata
```bash
sudo service netdata restart

# Check logs for errors
sudo tail -f /var/log/netdata/error.log | grep was110
```

## Verification

1. **Check Plugin Status**:
   ```bash
   # Verify plugin is running
   ps aux | grep was110.plugin

   # Check Netdata logs
   sudo tail /var/log/netdata/error.log
   ```

2. **View Dashboard**:
   - Open http://localhost:19999
   - Navigate to "was110" section
   - Verify all 7 charts are present and updating

3. **Expected Charts**:
   - **PLOAM State**: Should show 51 or 52 when connected
   - **Optical Power**: RX power around -20 dBm (varies by installation)
   - **Signal Quality**: Percentage based on RX power thresholds
   - **Temperature**: Optic and CPU temperatures
   - **Electrical**: Voltage (~3.3V) and TX bias current
   - **Connection Uptime**: Seconds in O5 state
   - **State Transitions**: Event counters

## PLOAM State Reference

| State | Name | Meaning |
|-------|------|---------|
| 51 | O5.1 Associated | ✅ Normal operation |
| 52 | O5.2 Operational | ✅ Also good |
| 10 | O1 Initial | Just powered on |
| 20/30 | O2-O3 Serial Number | Authenticating with OLT |
| 40 | O4 Ranging | Measuring distance/timing |
| 60 | O6 POPUP | Loss of signal, recovering |
| 70 | O7 Emergency Stop | Laser disabled by OLT |

## Signal Quality Reference

Based on AT&T XGS-PON residential experience:

| Quality | RX Power Range | Status |
|---------|----------------|--------|
| Excellent (100%) | -19 to -21 dBm | Optimal signal |
| Good (80%) | -21 to -25 dBm | Normal operation |
| Acceptable (60%) | -25 to -27 dBm | Monitor trends |
| Poor (40%) | -27 to -30 dBm | Check fiber/connectors |
| Critical (20%) | < -30 dBm | Service likely impacted |

## Troubleshooting

### Plugin Not Starting
```bash
# Check dependencies
python3 -c "import requests, urllib3; print('Dependencies OK')"

# Test with verbose logging
sudo -u netdata /usr/libexec/netdata/plugins.d/was110.plugin 2 2>&1

# Check file permissions
ls -la /usr/libexec/netdata/plugins.d/was110.plugin
ls -la /etc/netdata/was110.conf
```

### API Connection Issues
```bash
# Test API manually
curl -k -u root:8311 https://192.168.11.1/cgi-bin/luci/8311/metrics

# Check network connectivity
ping 192.168.11.1

# Verify WAS-110 firmware version
# (Should be 8311 community firmware v2.8.2+)
```

### Charts Not Appearing
```bash
# Restart Netdata
sudo service netdata restart

# Check for plugin errors
sudo tail -f /var/log/netdata/error.log | grep was110

# Verify plugin output format
sudo -u netdata /usr/libexec/netdata/plugins.d/was110.plugin 2 | head -20
```

### Common Issues

1. **SSL Certificate Errors**: Normal - plugin disables SSL verification for self-signed certs
2. **Timeout Errors**: Increase timeout in config or check network latency
3. **Authentication Errors**: Verify username/password in was110.conf
4. **Permission Errors**: Ensure netdata user can read config file
5. **Missing Charts**: Check that plugin outputs valid Netdata format

## Configuration Reference

### Global Settings
- `url`: WAS-110 API endpoint URL
- `username`: HTTP Basic Auth username (default: root)
- `password`: HTTP Basic Auth password
- `update_every`: Update interval in seconds (minimum 1, recommended 2-5)
- `timeout`: HTTP request timeout in seconds
- `log_level`: Logging verbosity (DEBUG, INFO, WARNING, ERROR)

### Threshold Settings
- `rx_power_excellent`: Excellent signal threshold in dBm
- `rx_power_good`: Good signal threshold in dBm
- `rx_power_acceptable`: Acceptable signal threshold in dBm
- `rx_power_poor`: Poor signal threshold in dBm

Adjust thresholds based on your specific fiber installation and ISP specifications.

## Performance Notes

- Each API call reads fresh data from the SFP I2C bus (~800ms response time)
- 2-second update interval provides real-time monitoring without overloading the device
- Plugin uses minimal CPU and memory resources
- All metrics stored with appropriate precision (hundredths for decimals)

## Integration with Alarms

Install the provided alarm configuration:
```bash
sudo cp was110-alarms.conf /etc/netdata/health.d/
sudo service netdata restart
```

This provides alerts for:
- PLOAM state changes (connection loss)
- Poor signal quality trends
- Temperature thresholds
- State transition anomalies

## License

MIT License - see LICENSE file for details.

## Support

- Check Netdata logs: `/var/log/netdata/error.log`
- Test API connectivity: `./was110-test.sh`
- Verify plugin output: `sudo -u netdata ./was110.plugin 2`
- WAS-110 firmware: [8311 Community Firmware](https://github.com/djGrrr/8311-was-110-firmware-builder)