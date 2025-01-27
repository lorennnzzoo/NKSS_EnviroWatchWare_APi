using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Post.Report
{
    public class ReportFilter
    {
        public int CompanyId { get; set; }
        public List<int> StationsId { get; set; } = new List<int>();
        public List<int> ChannelsId { get; set; } = new List<int>();
        public DataAggregationType DataAggregationType { get; set; }
        public DateTime? From { get; set; }
        public DateTime? To { get; set; }
        public ReportType ReportType { get; set; }
    }
    public enum DataAggregationType
    {
        Raw = 0,
        FifteenMin = 15,
        OneHour = 60 
    }
    public enum ReportType
    {
        DataAvailability = 1,
        DataReport = 2,
        Exceedance = 3,
        Windrose = 4,
        Trends = 5
    }

}
