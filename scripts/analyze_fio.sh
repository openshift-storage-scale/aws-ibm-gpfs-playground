#!/bin/bash

# Comprehensive FIO Problem Analysis Script
# Analyzes FIO logs for all potential I/O issues during live volume migrations

set -e

echo "🔍 FIO Problem Analysis Report"
echo "=============================="
echo ""

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "ERROR") echo -e "${RED}❌ ERROR:${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}⚠️  WARNING:${NC} $message" ;;
        "OK") echo -e "${GREEN}✅ OK:${NC} $message" ;;
        "INFO") echo -e "${BLUE}ℹ️  INFO:${NC} $message" ;;
    esac
}

# Function to analyze bandwidth problems
analyze_bandwidth() {
    echo "�� Bandwidth Analysis"
    echo "-------------------"
    
    for logfile in /home/fedora/fio_bw.*.log; do
        if [[ -f "$logfile" ]]; then
            echo "File: $(basename "$logfile")"
            
            # Calculate statistics with proper handling
            stats=$(awk 'NR>1 {
                sum+=$2; count++; 
                if($2<min||min=="") min=$2; 
                if($2>max) max=$2;
                if($2<1000) low_count++;
                if($2<100) very_low_count++;
            } END {
                if(count > 0) {
                    avg=sum/count;
                    print avg, min, max, low_count, very_low_count, count
                } else {
                    print "0 0 0 0 0 0"
                }
            }' "$logfile")
            
            read avg min max low_count very_low_count total <<< "$stats"
            
            # Format numbers properly
            avg_formatted=$(printf "%.0f" "$avg")
            min_formatted=$(printf "%.0f" "$min")
            max_formatted=$(printf "%.0f" "$max")
            
            echo "  Average: $avg_formatted KB/s"
            echo "  Range: $min_formatted - $max_formatted KB/s"
            echo "  Samples: $total"
            
            # Check for problems
            if (( avg_formatted < 1000 )); then
                print_status "ERROR" "Very low average bandwidth: $avg_formatted KB/s"
            elif (( avg_formatted < 5000 )); then
                print_status "WARNING" "Low average bandwidth: $avg_formatted KB/s"
            else
                print_status "OK" "Bandwidth performance is good"
            fi
            
            if (( very_low_count > 0 )); then
                print_status "ERROR" "$very_low_count samples with bandwidth < 100 KB/s (severe throttling)"
            fi
            
            if (( total > 0 && low_count > total/10 )); then
                percentage=$((low_count * 100 / total))
                print_status "WARNING" "$low_count samples with bandwidth < 1000 KB/s ($percentage% of samples)"
            fi
            
            echo ""
        fi
    done
}

# Function to analyze total latency problems
analyze_latency() {
    echo "⏱️  Total Latency Analysis"
    echo "------------------------"
    
    for logfile in /home/fedora/fio_lat.*.log; do
        if [[ -f "$logfile" ]]; then
            echo "File: $(basename "$logfile")"
            
            # Calculate statistics
            stats=$(awk 'NR>1 {
                sum+=$2; count++; 
                if($2<min||min=="") min=$2; 
                if($2>max) max=$2;
                if($2>10000) high_count++;
                if($2>50000) very_high_count++;
                if($2>100000) extreme_count++;
            } END {
                if(count > 0) {
                    avg=sum/count;
                    print avg, min, max, high_count, very_high_count, extreme_count, count
                } else {
                    print "0 0 0 0 0 0 0"
                }
            }' "$logfile")
            
            read avg min max high_count very_high_count extreme_count total <<< "$stats"
            
            # Format numbers properly
            avg_formatted=$(printf "%.0f" "$avg")
            min_formatted=$(printf "%.0f" "$min")
            max_formatted=$(printf "%.0f" "$max")
            
            echo "  Average: $avg_formatted μs"
            echo "  Range: $min_formatted - $max_formatted μs"
            echo "  Samples: $total"
            
            # Check for problems
            if (( avg_formatted > 10000 )); then
                print_status "ERROR" "Very high average latency: $avg_formatted μs"
            elif (( avg_formatted > 5000 )); then
                print_status "WARNING" "High average latency: $avg_formatted μs"
            else
                print_status "OK" "Total latency performance is good"
            fi
            
            if (( extreme_count > 0 )); then
                print_status "ERROR" "$extreme_count samples with latency > 100ms (extreme delays)"
            fi
            
            if (( very_high_count > 0 )); then
                print_status "WARNING" "$very_high_count samples with latency > 50ms (significant delays)"
            fi
            
            if (( total > 0 && high_count > total/20 )); then
                percentage=$((high_count * 100 / total))
                print_status "WARNING" "$high_count samples with latency > 10ms ($percentage% of samples)"
            fi
            
            echo ""
        fi
    done
}

# Function to analyze completion latency problems
analyze_completion_latency() {
    echo "⏱️  Completion Latency Analysis"
    echo "-----------------------------"
    
    for logfile in /home/fedora/fio_clat.*.log; do
        if [[ -f "$logfile" ]]; then
            echo "File: $(basename "$logfile")"
            
            # Calculate statistics
            stats=$(awk 'NR>1 {
                sum+=$2; count++; 
                if($2<min||min=="") min=$2; 
                if($2>max) max=$2;
                if($2>10000) high_count++;
                if($2>50000) very_high_count++;
                if($2>100000) extreme_count++;
            } END {
                if(count > 0) {
                    avg=sum/count;
                    print avg, min, max, high_count, very_high_count, extreme_count, count
                } else {
                    print "0 0 0 0 0 0 0"
                }
            }' "$logfile")
            
            read avg min max high_count very_high_count extreme_count total <<< "$stats"
            
            # Format numbers properly
            avg_formatted=$(printf "%.0f" "$avg")
            min_formatted=$(printf "%.0f" "$min")
            max_formatted=$(printf "%.0f" "$max")
            
            echo "  Average: $avg_formatted μs"
            echo "  Range: $min_formatted - $max_formatted μs"
            echo "  Samples: $total"
            
            # Check for problems
            if (( avg_formatted > 10000 )); then
                print_status "ERROR" "Very high average completion latency: $avg_formatted μs"
            elif (( avg_formatted > 5000 )); then
                print_status "WARNING" "High average completion latency: $avg_formatted μs"
            else
                print_status "OK" "Completion latency performance is good"
            fi
            
            if (( extreme_count > 0 )); then
                print_status "ERROR" "$extreme_count samples with completion latency > 100ms (extreme delays)"
            fi
            
            if (( very_high_count > 0 )); then
                print_status "WARNING" "$very_high_count samples with completion latency > 50ms (significant delays)"
            fi
            
            if (( total > 0 && high_count > total/20 )); then
                percentage=$((high_count * 100 / total))
                print_status "WARNING" "$high_count samples with completion latency > 10ms ($percentage% of samples)"
            fi
            
            echo ""
        fi
    done
}

# Function to analyze submission latency problems
analyze_submission_latency() {
    echo "⏱️  Submission Latency Analysis"
    echo "-----------------------------"
    
    for logfile in /home/fedora/fio_slat.*.log; do
        if [[ -f "$logfile" ]]; then
            echo "File: $(basename "$logfile")"
            
            # Calculate statistics
            stats=$(awk 'NR>1 {
                sum+=$2; count++; 
                if($2<min||min=="") min=$2; 
                if($2>max) max=$2;
                if($2>1000) high_count++;
                if($2>5000) very_high_count++;
                if($2>10000) extreme_count++;
            } END {
                if(count > 0) {
                    avg=sum/count;
                    print avg, min, max, high_count, very_high_count, extreme_count, count
                } else {
                    print "0 0 0 0 0 0 0"
                }
            }' "$logfile")
            
            read avg min max high_count very_high_count extreme_count total <<< "$stats"
            
            # Format numbers properly
            avg_formatted=$(printf "%.0f" "$avg")
            min_formatted=$(printf "%.0f" "$min")
            max_formatted=$(printf "%.0f" "$max")
            
            echo "  Average: $avg_formatted μs"
            echo "  Range: $min_formatted - $max_formatted μs"
            echo "  Samples: $total"
            
            # Check for problems
            if (( avg_formatted > 1000 )); then
                print_status "ERROR" "Very high average submission latency: $avg_formatted μs"
            elif (( avg_formatted > 500 )); then
                print_status "WARNING" "High average submission latency: $avg_formatted μs"
            else
                print_status "OK" "Submission latency performance is good"
            fi
            
            if (( extreme_count > 0 )); then
                print_status "ERROR" "$extreme_count samples with submission latency > 10ms (extreme delays)"
            fi
            
            if (( very_high_count > 0 )); then
                print_status "WARNING" "$very_high_count samples with submission latency > 5ms (significant delays)"
            fi
            
            if (( total > 0 && high_count > total/20 )); then
                percentage=$((high_count * 100 / total))
                print_status "WARNING" "$high_count samples with submission latency > 1ms ($percentage% of samples)"
            fi
            
            echo ""
        fi
    done
}

# Function to analyze IOPS problems
analyze_iops() {
    echo "�� IOPS Analysis"
    echo "---------------"
    
    for logfile in /home/fedora/fio_iops.*.log; do
        if [[ -f "$logfile" ]]; then
            echo "File: $(basename "$logfile")"
            
            # Calculate statistics
            stats=$(awk 'NR>1 {
                sum+=$2; count++; 
                if($2<min||min=="") min=$2; 
                if($2>max) max=$2;
                if($2<100) low_count++;
                if($2<10) very_low_count++;
            } END {
                if(count > 0) {
                    avg=sum/count;
                    print avg, min, max, low_count, very_low_count, count
                } else {
                    print "0 0 0 0 0 0"
                }
            }' "$logfile")
            
            read avg min max low_count very_low_count total <<< "$stats"
            
            # Format numbers properly
            avg_formatted=$(printf "%.0f" "$avg")
            min_formatted=$(printf "%.0f" "$min")
            max_formatted=$(printf "%.0f" "$max")
            
            echo "  Average: $avg_formatted IOPS"
            echo "  Range: $min_formatted - $max_formatted IOPS"
            echo "  Samples: $total"
            
            # Check for problems
            if (( avg_formatted < 100 )); then
                print_status "ERROR" "Very low average IOPS: $avg_formatted"
            elif (( avg_formatted < 500 )); then
                print_status "WARNING" "Low average IOPS: $avg_formatted"
            else
                print_status "OK" "IOPS performance is good"
            fi
            
            if (( very_low_count > 0 )); then
                print_status "ERROR" "$very_low_count samples with IOPS < 10 (severe throttling)"
            fi
            
            if (( total > 0 && low_count > total/10 )); then
                percentage=$((low_count * 100 / total))
                print_status "WARNING" "$low_count samples with IOPS < 100 ($percentage% of samples)"
            fi
            
            echo ""
        fi
    done
}

# Function to detect performance patterns
analyze_patterns() {
    echo "📈 Performance Pattern Analysis"
    echo "-----------------------------"
    
    # Check for sudden drops in performance
    for logfile in /home/fedora/fio_bw.*.log; do
        if [[ -f "$logfile" ]]; then
            echo "File: $(basename "$logfile")"
            
            # Find sudden drops (>50% decrease)
            drops=$(awk 'NR>2 {
                if(prev > 0 && $2 < prev * 0.5) {
                    print "Time:", strftime("%H:%M:%S", $1), "Drop from", int(prev), "to", int($2), "KB/s"
                }
                prev=$2
            }' "$logfile" | head -5)
            
            if [[ -n "$drops" ]]; then
                print_status "WARNING" "Detected sudden performance drops:"
                echo "$drops"
            else
                print_status "OK" "No sudden performance drops detected"
            fi
            
            echo ""
        fi
    done
}

# Function to check for data corruption indicators
check_corruption_indicators() {
    echo "🔒 Data Integrity Analysis"
    echo "------------------------"
    
    # Check golden checksums
    if [[ -f "/home/fedora/gold.sha256" ]]; then
        if sha256sum -c /home/fedora/gold.sha256 > /dev/null 2>&1; then
            print_status "OK" "Golden checksums verified - no data corruption detected"
        else
            print_status "ERROR" "Golden checksum verification failed - possible data corruption!"
        fi
    else
        print_status "WARNING" "Golden checksum file not found"
    fi
    
    # Check for FIO verification errors
    fio_errors=$(journalctl -u fio-test.service 2>/dev/null | grep -i "verify.*fail\|corrupt\|error" | wc -l)
    if [[ $fio_errors -eq 0 ]]; then
        print_status "OK" "No FIO verification errors detected"
    else
        print_status "ERROR" "Found $fio_errors FIO verification errors"
        journalctl -u fio-test.service 2>/dev/null | grep -i "verify.*fail\|corrupt\|error" | tail -5
    fi
    
    # Check kernel logs for I/O errors
    kernel_errors=$(journalctl -k --since "3 hours ago" 2>/dev/null | grep -i "i/o error\|buffer i/o error\|xfs.*error\|corrupt" | wc -l)
    if [[ $kernel_errors -eq 0 ]]; then
        print_status "OK" "No kernel I/O errors detected"
    else
        print_status "ERROR" "Found $kernel_errors kernel I/O errors"
        journalctl -k --since "3 hours ago" 2>/dev/null | grep -i "i/o error\|buffer i/o error\|xfs.*error\|corrupt" | tail -5
    fi
    
    echo ""
}

# Function to generate summary report
generate_summary() {
    echo "📋 Summary Report"
    echo "================"
    
    # Count log files
    bw_files=$(ls /home/fedora/fio_bw.*.log 2>/dev/null | wc -l)
    lat_files=$(ls /home/fedora/fio_lat.*.log 2>/dev/null | wc -l)
    clat_files=$(ls /home/fedora/fio_clat.*.log 2>/dev/null | wc -l)
    slat_files=$(ls /home/fedora/fio_slat.*.log 2>/dev/null | wc -l)
    iops_files=$(ls /home/fedora/fio_iops.*.log 2>/dev/null | wc -l)
    
    echo "Log files found:"
    echo "  - Bandwidth logs: $bw_files"
    echo "  - Total latency logs: $lat_files"
    echo "  - Completion latency logs: $clat_files"
    echo "  - Submission latency logs: $slat_files"
    echo "  - IOPS logs: $iops_files"
    
    echo ""
    echo "Overall Assessment:"
    print_status "INFO" "Analysis complete - check individual sections above for detailed results"
    
    echo ""
    echo "Recommendations:"
    echo "  - Review any ERROR or WARNING messages above"
    echo "  - Monitor performance during future migrations"
    echo "  - Consider optimizing storage configuration if issues found"
}

# Main execution
main() {
    echo "Starting comprehensive FIO problem analysis..."
    echo "Analysis time: $(date)"
    echo ""
    
    # Check if we're in the right directory
    if [[ ! -d "/home/fedora" ]]; then
        print_status "ERROR" "This script must be run from within the VM"
        exit 1
    fi
    
    # Run all analyses
    analyze_bandwidth
    analyze_latency
    analyze_completion_latency
    analyze_submission_latency
    analyze_iops
    analyze_patterns
    check_corruption_indicators
    generate_summary
    
    echo ""
    echo "Analysis complete at: $(date)"
}

# Run the analysis
main "$@"