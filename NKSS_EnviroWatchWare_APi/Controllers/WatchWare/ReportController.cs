using Services;
using System;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace NKSS_EnviroWatchWare_APi.Controllers
{
    [Authorize]
    [RoutePrefix("Report")]

    public class ReportController : ApiController
    {
        private readonly ReportService report_service;        
        public ReportController(ReportService _report_service)
        {
            this.report_service = _report_service;
        }
        [HttpPost]
        [Route("GetReport")]
        public IHttpActionResult GetReport(Models.Post.Report.ReportFilter filter)
        {
            try
            {
                
                filter.StationsId.Remove(0);
                filter.ChannelsId.Remove(0);

                //var result = validator.ValidateProperties(filter);
                //if (!result.isValid)
                //{
                //    return BadRequest(result.errorMessage);
                //}
                if (filter.CompanyId == 0)
                {
                    throw new ArgumentException("Select Parameters");
                }
                if (filter.From == null || filter.To == null)
                {
                    throw new ArgumentException("Please Choose From and To");
                }
                if (filter.From > filter.To)
                {
                    throw new ArgumentException("'From' date cannot be greater than 'To' date.");
                }
                if (filter.To - filter.From > TimeSpan.FromDays(366))
                {
                    throw new ArgumentException("Cannot fetch data longer than one year at once.");
                }
                var reportData = report_service.GetReport(filter);
                return Ok(reportData);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }


        [HttpGet]
        [Route("GetSelectionData")]
        public IHttpActionResult GetSelectionData()
        {
            try
            {

                var reportData = report_service.GetSelectionModel();
                return Ok(reportData);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

    }
}
