using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.AutoMailReport
{
    public class ReportSubscription
    {
        public Guid Id { get; set; }
        public int StationId { get; set; }
        public List<int> ChannelIds { get; set; } = new List<int>();
        public Models.Post.Report.DataAggregationType Interval { get; set; }
        public ReportRange Range { get; set; }
        public TimeSpan EmailScheduleTime { get; set; }
        public EmailFrequency Frequency { get; set; }
    }
    public enum ReportRange
    {
        PastDay,
        PastWeek,
        PastMonth
    }

    public enum EmailFrequency
    {
        Daily,
        Weekly,
        Monthly
    }
}
