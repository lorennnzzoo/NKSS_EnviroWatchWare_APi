using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Interfaces
{
    public interface IAutoMailReportService
    {
        void CreateSubscription(Models.AutoMailReport.ReportSubscription subscription);
        IEnumerable<Models.AutoMailReport.ReportSubscription> GetSubscriptions();
    }
}
