﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Exceptions
{
    public class CompaniesLimitReachedException : Exception
    {
        public CompaniesLimitReachedException()
           : base($"Cannot create more than 1 company")
        {
        }
    }
}
