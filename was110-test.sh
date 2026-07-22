#!/usr/bin/env bash
#
# WAS-110 API Test Script
# Tests connectivity and API response from WAS-110 device
#

# Default configuration
WAS110_URL="https://192.168.11.1/cgi-bin/luci/8311/metrics"
WAS110_USER="root"
WAS110_PASS="8311"
CONFIG_FILE="${NETDATA_USER_CONFIG_DIR:-/etc/netdata}/was110.conf"

# Colors for output
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m' # No Color

print_header() {
    echo "${BLUE}=== WAS-110 API Test Script ===${NC}"
    echo
}

print_success() {
    echo "${GREEN}✓${NC} $1"
}

print_warning() {
    echo "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo "${RED}✗${NC} $1"
}

print_info() {
    echo "${BLUE}ℹ${NC} $1"
}

# Load configuration if available
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        print_info "Loading configuration from $CONFIG_FILE"

        # Parse config file for URL, username, password
        if command -v python3 >/dev/null 2>&1; then
            eval "$(python3 -c "
import configparser, sys
try:
    config = configparser.ConfigParser()
    config.read('$CONFIG_FILE')
    if 'global' in config:
        if 'url' in config['global']:
            print(f'WAS110_URL=\"{config[\"global\"][\"url\"]}\"')
        if 'username' in config['global']:
            print(f'WAS110_USER=\"{config[\"global\"][\"username\"]}\"')
        if 'password' in config['global']:
            print(f'WAS110_PASS=\"{config[\"global\"][\"password\"]}\"')
except Exception as e:
    print(f'# Error reading config: {e}', file=sys.stderr)
" 2>/dev/null)"
        fi
    else
        print_warning "Configuration file $CONFIG_FILE not found, using defaults"
    fi
}

# Test network connectivity
test_connectivity() {
    print_info "Testing network connectivity..."

    # Extract hostname from URL
    HOSTNAME=$(echo "$WAS110_URL" | sed 's|https\?://||g' | sed 's|/.*||g')

    if ping -c 1 -W 3000 "$HOSTNAME" >/dev/null 2>&1; then
        print_success "Network connectivity to $HOSTNAME OK"
        return 0
    else
        print_error "Cannot ping $HOSTNAME"
        return 1
    fi
}

# Test API endpoint
test_api() {
    print_info "Testing WAS-110 API endpoint..."
    print_info "URL: $WAS110_URL"
    print_info "Username: $WAS110_USER"
    print_info "Password: [${#WAS110_PASS} characters]"
    echo

    # Test with curl
    if command -v curl >/dev/null 2>&1; then
        RESPONSE=$(curl -s -k -u "${WAS110_USER}:${WAS110_PASS}" \
                       -w "HTTPCODE:%{http_code}" \
                       --connect-timeout 5 \
                       --max-time 10 \
                       "$WAS110_URL" 2>/dev/null)

        HTTP_CODE=$(echo "$RESPONSE" | grep -o "HTTPCODE:[0-9]*" | cut -d: -f2)
        JSON_DATA=$(echo "$RESPONSE" | sed 's/HTTPCODE:[0-9]*$//')

        if [ "$HTTP_CODE" = "200" ]; then
            print_success "HTTP request successful (200 OK)"

            # Validate JSON response
            if echo "$JSON_DATA" | python3 -m json.tool >/dev/null 2>&1; then
                print_success "Valid JSON response received"
                echo
                print_info "API Response:"
                echo "${GREEN}$(echo "$JSON_DATA" | python3 -m json.tool)${NC}"
                echo

                # Parse and display key metrics
                print_info "Key Metrics:"
                echo "$JSON_DATA" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(f'  PLOAM State: {data.get(\"ploam_state\", \"N/A\")}')
    print(f'  RX Power: {data.get(\"rx_power_dBm\", \"N/A\")} dBm')
    print(f'  TX Power: {data.get(\"tx_power_dBm\", \"N/A\")} dBm')
    print(f'  Optic Temp: {data.get(\"optic_tempC\", \"N/A\")}°C')
    print(f'  Module Voltage: {data.get(\"module_voltage\", \"N/A\")}V')
    print(f'  TX Bias: {data.get(\"tx_bias_mA\", \"N/A\")}mA')

    # PLOAM state interpretation
    ploam_state = data.get('ploam_state', 0)
    if ploam_state in [51, 52]:
        print(f'  Status: ✅ Connected (O5 state)')
    elif ploam_state == 10:
        print(f'  Status: ⏳ Initial state (O1)')
    elif ploam_state in [20, 30]:
        print(f'  Status: 🔐 Authenticating (O2-O3)')
    elif ploam_state == 40:
        print(f'  Status: 📐 Ranging (O4)')
    elif ploam_state == 60:
        print(f'  Status: ⚠️  Loss of signal (O6)')
    elif ploam_state == 70:
        print(f'  Status: 🛑 Emergency stop (O7)')
    else:
        print(f'  Status: ❓ Unknown state')

    # Signal quality assessment
    rx_power = data.get('rx_power_dBm', -999)
    if rx_power != -999:
        if rx_power >= -21:
            quality = 'Excellent'
        elif rx_power >= -25:
            quality = 'Good'
        elif rx_power >= -27:
            quality = 'Acceptable'
        elif rx_power >= -30:
            quality = 'Poor'
        else:
            quality = 'Critical'
        print(f'  Signal Quality: {quality}')
except Exception as e:
    print(f'Error parsing JSON: {e}')
" 2>/dev/null

                return 0
            else
                print_error "Invalid JSON response"
                print_info "Raw response: $JSON_DATA"
                return 1
            fi
        elif [ "$HTTP_CODE" = "401" ]; then
            print_error "Authentication failed (401 Unauthorized)"
            print_warning "Check username and password in configuration"
            return 1
        elif [ "$HTTP_CODE" = "404" ]; then
            print_error "API endpoint not found (404)"
            print_warning "Check URL and firmware version"
            return 1
        else
            print_error "HTTP request failed (code: $HTTP_CODE)"
            print_info "Response: $JSON_DATA"
            return 1
        fi
    else
        print_error "curl not found, cannot test API"
        return 1
    fi
}

# Test Python dependencies
test_dependencies() {
    print_info "Testing Python dependencies..."

    if command -v python3 >/dev/null 2>&1; then
        print_success "Python 3 found: $(python3 --version)"
    else
        print_error "Python 3 not found"
        return 1
    fi

    # Test required modules
    for module in requests urllib3 json configparser; do
        if python3 -c "import $module" 2>/dev/null; then
            print_success "Python module '$module' available"
        else
            print_error "Python module '$module' not found"
            print_warning "Install with: pip install $module"
            return 1
        fi
    done

    return 0
}

# Test plugin execution
test_plugin() {
    print_info "Testing plugin execution..."

    PLUGIN_PATH="./was110.plugin"
    if [ ! -f "$PLUGIN_PATH" ]; then
        PLUGIN_PATH="/usr/libexec/netdata/plugins.d/was110.plugin"
    fi

    if [ ! -f "$PLUGIN_PATH" ]; then
        print_error "Plugin not found at $PLUGIN_PATH"
        return 1
    fi

    if [ ! -x "$PLUGIN_PATH" ]; then
        print_error "Plugin not executable: $PLUGIN_PATH"
        return 1
    fi

    print_success "Plugin found: $PLUGIN_PATH"

    # Test plugin output (first 20 lines)
    print_info "Testing plugin output (first 20 lines):"
    PLUGIN_OUTPUT=$(timeout 10 "$PLUGIN_PATH" 2 2>/dev/null)
    PLUGIN_RC=$?

    echo "$PLUGIN_OUTPUT" | head -20

    # timeout returns 124 on timeout (expected — we kill the long-running plugin)
    if [ $PLUGIN_RC -eq 0 ] || [ $PLUGIN_RC -eq 124 ]; then
        # Verify we got valid Netdata output
        if echo "$PLUGIN_OUTPUT" | grep -q "^CHART "; then
            print_success "Plugin produced valid chart definitions"
            return 0
        else
            print_error "Plugin ran but produced no chart definitions"
            return 1
        fi
    else
        print_error "Plugin execution failed (exit code: $PLUGIN_RC)"
        return 1
    fi
}

# Main execution
main() {
    print_header

    load_config
    echo

    # Run all tests
    FAILURES=0

    test_dependencies || FAILURES=$((FAILURES + 1))
    echo

    test_connectivity || FAILURES=$((FAILURES + 1))
    echo

    test_api || FAILURES=$((FAILURES + 1))
    echo

    test_plugin || FAILURES=$((FAILURES + 1))
    echo

    # Summary
    if [ $FAILURES -eq 0 ]; then
        print_success "All tests passed! WAS-110 plugin should work correctly."
    else
        print_error "$FAILURES test(s) failed. Check the errors above."
        echo
        print_info "Common solutions:"
        echo "  - Install Python dependencies: pip install requests urllib3"
        echo "  - Check WAS-110 is accessible at $WAS110_URL"
        echo "  - Verify username/password in $CONFIG_FILE"
        echo "  - Ensure WAS-110 runs 8311 firmware v2.8.2+"
        exit 1
    fi
}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  -h, --help    Show this help message"
        echo "  -q, --quiet   Quiet mode (minimal output)"
        echo
        echo "This script tests connectivity and functionality of the WAS-110"
        echo "Netdata plugin by checking network connectivity, API access,"
        echo "Python dependencies, and plugin execution."
        echo
        echo "Configuration is loaded from $CONFIG_FILE if available."
        exit 0
        ;;
    -q|--quiet)
        # Redirect to suppress colors and extra output
        exec >/dev/null 2>&1
        main
        ;;
    *)
        main
        ;;
esac