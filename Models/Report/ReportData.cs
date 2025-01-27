using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Report
{    
    public class ChannelDataReport
    {
        public DateTime ChannelDataLogTime { get; set; }
        public Dictionary<string, string> DynamicColumns { get; set; }
    }


    public class ChannelDataExceedanceReport
    {
        public DateTime ChannelDataLogTime { get; set; }
        public Dictionary<string, string> DynamicColumns { get; set; }
    }

}
