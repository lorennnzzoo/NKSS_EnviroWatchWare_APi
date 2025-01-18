using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Put
{
    public class Company
    {
        public int? Id { get; set; }
        public string ShortName { get; set; }
        public string LegalName { get; set; }
        public string Country { get; set; }
        public string State { get; set; }
        public string District { get; set; }
        public string Address { get; set; }
        public string PinCode { get; set; }
        public byte[] Logo { get; set; }
    }
}
